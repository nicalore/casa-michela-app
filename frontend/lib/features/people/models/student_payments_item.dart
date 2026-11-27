// A member's «Pagamenti» tab as GET /people/{tax_code}/payments sends it: a pupil's tariff, everyone's fees.

class StudentTariffItem
{
  // HOURLY, PACKAGE or MONTHLY.
  final String kind;

  // Per hour, or what the next package or month costs: the last bought, else the agreed one.
  final int amountCents;

  final int? packageHours;

  // When it began to count, which a package before it may have delayed.
  final DateTime startsOn;

  const StudentTariffItem({
    required this.kind,
    required this.amountCents,
    this.packageHours,
    required this.startsOn,
  });

  bool get isHourly => kind == 'HOURLY';
  bool get isPackage => kind == 'PACKAGE';
  bool get isMonthly => kind == 'MONTHLY';

  factory StudentTariffItem.fromJson(Map<String, dynamic> json)
  {
    return StudentTariffItem(
      kind: json['kind'] as String,
      amountCents: json['amount_cents'] as int,
      packageHours: json['package_hours'] as int?,
      startsOn: DateTime.parse(json['starts_on'] as String),
    );
  }
}

class PackageStatusItem
{
  final int totalMinutes;
  final int usedMinutes;

  // The day of the lesson that used the last minute.
  final DateTime? endedOn;

  const PackageStatusItem({
    required this.totalMinutes,
    required this.usedMinutes,
    this.endedOn,
  });

  int get leftMinutes => totalMinutes > usedMinutes ? totalMinutes - usedMinutes : 0;

  bool get running => leftMinutes > 0;

  factory PackageStatusItem.fromJson(Map<String, dynamic> json)
  {
    final String? ended = json['ended_on'] as String?;

    return PackageStatusItem(
      totalMinutes: json['total_minutes'] as int,
      usedMinutes: json['used_minutes'] as int,
      endedOn: ended == null ? null : DateTime.parse(ended),
    );
  }
}

// The hours paid ahead not used up yet, however many payments.
class AheadStatusItem
{
  final int totalMinutes;
  final int usedMinutes;

  const AheadStatusItem({required this.totalMinutes, required this.usedMinutes});

  int get leftMinutes => totalMinutes > usedMinutes ? totalMinutes - usedMinutes : 0;

  factory AheadStatusItem.fromJson(Map<String, dynamic> json)
  {
    return AheadStatusItem(
      totalMinutes: json['total_minutes'] as int,
      usedMinutes: json['used_minutes'] as int,
    );
  }
}

enum MonthState { paid, due, none }

class MonthStateItem
{
  // Its first day.
  final DateTime month;
  final MonthState state;

  const MonthStateItem({required this.month, required this.state});

  factory MonthStateItem.fromJson(Map<String, dynamic> json)
  {
    return MonthStateItem(
      month: DateTime.parse(json['month'] as String),
      state: switch (json['state'])
      {
        'PAID' => MonthState.paid,
        'DUE' => MonthState.due,
        _ => MonthState.none,
      },
    );
  }
}

// The minutes of one lesson a line counts.
class LessonPartItem
{
  final DateTime day;
  final int minutes;

  // Under the tariff running now.
  final bool current;

  // Owed before the app kept the accounts, as the initial set-up says.
  final bool opening;

  // At the line's own rate, which settling keeps unless another is asked.
  final int cents;

  const LessonPartItem({
    required this.day,
    required this.minutes,
    required this.current,
    this.opening = false,
    this.cents = 0,
  });

  factory LessonPartItem.fromJson(Map<String, dynamic> json)
  {
    return LessonPartItem(
      day: DateTime.parse(json['day'] as String),
      minutes: json['minutes'] as int,
      current: json['current'] as bool? ?? false,
      opening: json['opening'] as bool? ?? false,
      cents: json['cents'] as int? ?? 0,
    );
  }
}

// Hours to settle by the hour: HOURLY, OVER_PACKAGE, OVER_FEE or WEEKEND_ONLINE.
class HoursLineItem
{
  final String kind;
  final int minutes;
  final int cents;
  final int centsPerHour;
  final List<LessonPartItem> parts;

  // A lesson of another row of its kind falls between its first and last day.
  final bool interleaved;

  const HoursLineItem({
    required this.kind,
    required this.minutes,
    required this.cents,
    required this.centsPerHour,
    this.parts = const [],
    this.interleaved = false,
  });

  bool get isWeekendOnline => kind == 'WEEKEND_ONLINE';

  DateTime? get firstDay => parts.isEmpty ? null : parts.first.day;
  DateTime? get lastDay => parts.isEmpty ? null : parts.last.day;

  int minutesWhere(bool Function(LessonPartItem part) test)
  {
    return parts.where(test).fold(0, (sum, part) => sum + part.minutes);
  }

  factory HoursLineItem.fromJson(Map<String, dynamic> json)
  {
    return HoursLineItem(
      kind: json['kind'] as String,
      minutes: json['minutes'] as int,
      cents: json['cents'] as int,
      centsPerHour: json['cents_per_hour'] as int,
      parts: (json['parts'] as List<dynamic>? ?? const [])
          .map((part) => LessonPartItem.fromJson(part as Map<String, dynamic>))
          .toList(),
      interleaved: json['interleaved'] as bool? ?? false,
    );
  }
}

// A lesson, or the part of it, that one payment covers.
class PaymentHistoryLesson
{
  final DateTime day;
  final int minutes;

  // The whole lesson's, more than [minutes] when another payment has the rest.
  final int lessonMinutes;

  // Packages and hours paid ahead: what is left after it.
  final int? leftMinutes;

  // Hours paid by the hour: what it costs.
  final int? cents;

  final bool exhausted;

  // Before it was paid: taken at the package's renewal, or with the hours paid ahead.
  final bool beforePayment;

  // Taken or owed before the app kept the accounts, as the initial set-up says.
  final bool opening;

  const PaymentHistoryLesson({
    required this.day,
    required this.minutes,
    required this.lessonMinutes,
    this.leftMinutes,
    this.cents,
    this.exhausted = false,
    this.beforePayment = false,
    this.opening = false,
  });

  bool get isPart => lessonMinutes > minutes;

  factory PaymentHistoryLesson.fromJson(Map<String, dynamic> json)
  {
    return PaymentHistoryLesson(
      day: DateTime.parse(json['day'] as String),
      minutes: json['minutes'] as int,
      lessonMinutes: json['lesson_minutes'] as int,
      leftMinutes: json['left_minutes'] as int?,
      cents: json['cents'] as int?,
      exhausted: json['exhausted'] as bool? ?? false,
      beforePayment: json['before_payment'] as bool? ?? false,
      opening: json['opening'] as bool? ?? false,
    );
  }
}

// RUNNING, ENDED, WAITING (paid ahead) or UNUSED; WAITING also for a fee after a package.
enum PaymentHistoryState { running, ended, waiting, unused }

// One payment, or what is still to pay, with the lessons it covers.
class PaymentHistoryRow
{
  // PACKAGE, MONTH, AHEAD (hours paid ahead), WEEKEND_AHEAD (online at the weekend paid ahead), the hours:
  // HOURLY, OVER_PACKAGE, OVER_FEE, WEEKEND_ONLINE,
  // or an annual fee: MEMBERSHIP_FEE, INSURANCE_FEE.
  final String kind;

  // Null while still to pay.
  final DateTime? paidOn;
  final String? paymentMethod;
  final String? paymentMethodOther;

  final int amountCents;
  final int minutes;
  final int? packageHours;
  final int? aheadMinutes;

  // A month's fee; null while it waits for a package to end.
  final DateTime? month;

  final PaymentHistoryState? state;

  // The newest first.
  final List<PaymentHistoryLesson> lessons;

  // Annual fees: the membership year and the row to settle.
  final int? year;
  final int? feeId;

  // Annual fees: the day the fee was recorded.
  final DateTime? recordedOn;

  // A lesson of another row of its kind falls between its first and last day.
  final bool interleaved;

  // A payment made, which can be cancelled.
  final int? paymentId;

  const PaymentHistoryRow({
    required this.kind,
    this.paidOn,
    this.paymentMethod,
    this.paymentMethodOther,
    required this.amountCents,
    required this.minutes,
    this.packageHours,
    this.aheadMinutes,
    this.month,
    this.state,
    this.lessons = const [],
    this.year,
    this.feeId,
    this.recordedOn,
    this.interleaved = false,
    this.paymentId,
  });

  bool get isPaid => paidOn != null;
  bool get canCancel => isPaid && (isFee ? feeId != null : paymentId != null);
  bool get isFee => kind == 'MEMBERSHIP_FEE' || kind == 'INSURANCE_FEE';
  bool get isPackage => kind == 'PACKAGE';
  bool get isMonth => kind == 'MONTH';
  // By the hour or online at the weekend: both count down what was bought.
  bool get isAhead => kind == 'AHEAD' || isWeekendAhead;
  bool get isWeekendAhead => kind == 'WEEKEND_AHEAD';

  // Hours bought in a block, each lesson saying what is left.
  bool get countsDown => isPackage || isAhead;

  // By the hour, so each lesson has its cost.
  bool get isHours => !isPackage && !isMonth && !isAhead && !isFee;

  DateTime? get firstDay => lessons.isEmpty ? null : lessons.last.day;
  DateTime? get lastDay => lessons.isEmpty ? null : lessons.first.day;

  static PaymentHistoryState? _state(String? raw)
  {
    return switch (raw)
    {
      'RUNNING' => PaymentHistoryState.running,
      'ENDED' => PaymentHistoryState.ended,
      'WAITING' => PaymentHistoryState.waiting,
      'UNUSED' => PaymentHistoryState.unused,
      _ => null,
    };
  }

  factory PaymentHistoryRow.fromJson(Map<String, dynamic> json)
  {
    final String? paidOn = json['paid_on'] as String?;
    final String? month = json['month'] as String?;

    return PaymentHistoryRow(
      kind: json['kind'] as String,
      paidOn: paidOn == null ? null : DateTime.parse(paidOn),
      paymentMethod: json['payment_method'] as String?,
      paymentMethodOther: json['payment_method_other'] as String?,
      amountCents: json['amount_cents'] as int,
      minutes: json['minutes'] as int,
      packageHours: json['package_hours'] as int?,
      aheadMinutes: json['ahead_minutes'] as int?,
      month: month == null ? null : DateTime.parse(month),
      state: _state(json['state'] as String?),
      lessons: (json['lessons'] as List<dynamic>? ?? const [])
          .map((lesson) => PaymentHistoryLesson.fromJson(lesson as Map<String, dynamic>))
          .toList(),
      year: json['year'] as int?,
      feeId: json['fee_id'] as int?,
      recordedOn: json['recorded_on'] == null ? null : DateTime.parse(json['recorded_on'] as String),
      interleaved: json['interleaved'] as bool? ?? false,
      paymentId: json['payment_id'] as int?,
    );
  }
}

enum PaymentState { ok, due, renew }

// Paid ahead and not started yet: one at a time, the buttons wait for it.
enum QueuedPayment { package, month, change }

class StudentPaymentsItem
{
  // Members who are not pupils have only their annual fees.
  final bool student;

  // Not enrolled: nothing new to buy, only what is owed to settle.
  final bool readOnly;

  final StudentTariffItem? tariff;

  // As SchoolLevel spells it; null without a school year on record.
  final String? schoolLevel;

  // The last payment's, else the one in the record.
  final String? paymentMethod;
  final String? paymentMethodOther;

  // Null without a tariff.
  final PaymentState? state;
  final int dueCents;

  // The package running, or the last one when all are used.
  final PackageStatusItem? package;
  final List<MonthStateItem>? months;

  // Hourly tariff only: what was paid ahead and is not used up.
  final AheadStatusItem? ahead;

  // Any tariff: online at the weekend paid ahead and not used up.
  final AheadStatusItem? weekendAhead;

  // What an online hour at the weekend costs at the pupil's level.
  final int? weekendOnlineCents;

  final List<HoursLineItem> lines;

  final QueuedPayment? queued;

  // The day a queued change starts; null when it waits for the package or the hours paid ahead to end.
  final DateTime? queuedStartsOn;

  // The tariff a queued change brings in.
  final StudentTariffItem? queuedTariff;

  // Every payment, those still to pay first, then the newest.
  final List<PaymentHistoryRow> history;

  // Listed in the initial set-up: PENDING or DONE; null otherwise.
  final String? opening;

  // The day the set-up describes, while listed.
  final DateTime? openingDay;

  const StudentPaymentsItem({
    this.student = true,
    this.readOnly = false,
    this.tariff,
    this.schoolLevel,
    this.paymentMethod,
    this.paymentMethodOther,
    this.state,
    this.dueCents = 0,
    this.package,
    this.months,
    this.ahead,
    this.weekendAhead,
    this.weekendOnlineCents,
    this.lines = const [],
    this.queued,
    this.queuedStartsOn,
    this.queuedTariff,
    this.history = const [],
    this.opening,
    this.openingDay,
  });

  // Until the set-up says how the pupil stood, nothing but the fees is paid here.
  bool get openingPending => opening == 'PENDING';

  HoursLineItem? line(String kind)
  {
    for (final HoursLineItem line in lines)
    {
      if (line.kind == kind)
      {
        return line;
      }
    }

    return null;
  }

  // Whether this month's fee is paid, for a monthly tariff.
  bool monthPaid(DateTime today)
  {
    for (final MonthStateItem month in months ?? const <MonthStateItem>[])
    {
      if (month.month.year == today.year && month.month.month == today.month)
      {
        return month.state == MonthState.paid;
      }
    }

    return false;
  }

  static PaymentState? _state(String? raw)
  {
    return switch (raw)
    {
      'OK' => PaymentState.ok,
      'DUE' => PaymentState.due,
      'RENEW' => PaymentState.renew,
      _ => null,
    };
  }

  static QueuedPayment? _queued(String? raw)
  {
    return switch (raw)
    {
      'PACKAGE' => QueuedPayment.package,
      'MONTH' => QueuedPayment.month,
      'CHANGE' => QueuedPayment.change,
      _ => null,
    };
  }

  factory StudentPaymentsItem.fromJson(Map<String, dynamic> json)
  {
    final Map<String, dynamic>? tariff = json['tariff'] as Map<String, dynamic>?;
    final Map<String, dynamic>? package = json['package'] as Map<String, dynamic>?;
    final List<dynamic>? months = json['months'] as List<dynamic>?;
    final Map<String, dynamic>? ahead = json['ahead'] as Map<String, dynamic>?;
    final Map<String, dynamic>? weekendAhead = json['weekend_ahead'] as Map<String, dynamic>?;
    final String? queuedStartsOn = json['queued_starts_on'] as String?;
    final Map<String, dynamic>? queuedTariff = json['queued_tariff'] as Map<String, dynamic>?;

    return StudentPaymentsItem(
      student: json['student'] as bool? ?? true,
      readOnly: json['read_only'] as bool? ?? false,
      tariff: tariff == null ? null : StudentTariffItem.fromJson(tariff),
      schoolLevel: json['school_level'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentMethodOther: json['payment_method_other'] as String?,
      state: _state(json['state'] as String?),
      dueCents: json['due_cents'] as int? ?? 0,
      package: package == null ? null : PackageStatusItem.fromJson(package),
      months: months
          ?.map((month) => MonthStateItem.fromJson(month as Map<String, dynamic>))
          .toList(),
      ahead: ahead == null ? null : AheadStatusItem.fromJson(ahead),
      weekendAhead: weekendAhead == null ? null : AheadStatusItem.fromJson(weekendAhead),
      weekendOnlineCents: json['weekend_online_cents'] as int?,
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((line) => HoursLineItem.fromJson(line as Map<String, dynamic>))
          .toList(),
      queued: _queued(json['queued'] as String?),
      queuedStartsOn: queuedStartsOn == null ? null : DateTime.parse(queuedStartsOn),
      queuedTariff: queuedTariff == null ? null : StudentTariffItem.fromJson(queuedTariff),
      history: (json['history'] as List<dynamic>? ?? const [])
          .map((row) => PaymentHistoryRow.fromJson(row as Map<String, dynamic>))
          .toList(),
      opening: json['opening'] as String?,
      openingDay: json['opening_day'] == null ? null : DateTime.parse(json['opening_day'] as String),
    );
  }
}
