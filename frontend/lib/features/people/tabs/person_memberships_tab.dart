import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/card_scroll_area.dart';
import '../../../shared/widgets/whole_words.dart';
import '../../association/tabs/opening_hours/hours_grid.dart' show TodayFrame;
import '../../association/tabs/opening_hours/lost_calendars.dart';
import '../models/membership_item.dart';
import '../models/person_item.dart';
import '../edit/person_edit_dialog.dart';
import '../../../shared/export/pdf_tab.dart';
import '../utils/cessation_form.dart';
import '../widgets/collaboration_badge.dart';
import '../widgets/revoke_membership_dialog.dart';
import 'person_account_shared.dart';
import '../widgets/membership_edit_row.dart';
import '../widgets/person_detail_widgets.dart';

const double _cardsWidth = 1600;

const double _cardPadding = 26;
const double _cardRadius = 32;
const double _headerHeight = 64;
const double _headerGap = 18;
const double _rowRadius = 20;
const double _currentPaddingH = 24;
const double _currentPaddingV = 15;
const double _tableHeadHeight = 38;
const double _tableRowHeight = 46;
const double _tablePaddingH = 24;
const double _tableBorder = 1.5;

// Inside a dense page (AppPageDensity), as the other cards there.
const EdgeInsets _denseCardPadding = EdgeInsets.fromLTRB(20, 16, 20, 18);
const double _denseCardRadius = 24;
const double _denseHeaderHeight = 40;
const double _denseHeaderGap = 12;
const double _denseRuleSpace = 13;
const double _denseRowRadius = 16;
const double _denseCurrentPaddingH = 12;
const double _denseCurrentPaddingV = 10;
const double _denseGridGap = 12;
const double _denseTableHeadHeight = 34;
const double _denseTableRowHeight = 40;
const double _denseTablePaddingH = 12;

Color get _revokedSurface => ThemeColours.fixed(0xFFFBEDEA);
Color get _revokedRowSurface => ThemeColours.fixed(0xFFFDF4F2);
Color get _tableHeadSurface => ThemeColours.of(0xFFF5F8F8);
Color get _tableRule => ThemeColours.of(0xFFEDF2F1);

Map<String, String> get _revocationLabels => {
  MembershipItem.revocationExpulsion: tr('Esclusione', 'Expulsion'),
  MembershipItem.revocationResignation: tr('Dimissioni', 'Resignation'),
};

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
final DateFormat _dayMonthFormat = DateFormat('dd/MM');

String get kNoMembershipsMessage => tr('Nessuna iscrizione registrata.', 'No enrolments recorded.');

String membershipStatusLabel({required bool isEnrolled, required bool isFemale})
{
  return isEnrolled
      ? (isFemale ? tr('Iscritta', 'Enrolled') : tr('Iscritto', 'Enrolled'))
      : (isFemale ? tr('Non iscritta', 'Not enrolled') : tr('Non iscritto', 'Not enrolled'));
}

String revokedMembershipLabel(MembershipItem membership)
{
  final String reason = _revocationLabels[membership.revocation] ?? membership.revocation;

  return tr('Iscrizione revocata ($reason)', 'Enrolment revoked ($reason)');
}

TextStyle _labelStyle(double size)
{
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: AppTheme.trialMutedText,
  );
}

TextStyle _valueStyle(double size, {bool strong = false, Color? color})
{
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
    color: color ?? (strong ? AppTheme.trialOceanText : AppTheme.trialInk),
  );
}

// A membership counts as running until the renewal window has passed, not on the end date itself.
class PersonMembershipsTab extends StatelessWidget
{
  final PersonItem person;

  // Null for read-only viewers (e.g. a parent): hides the edit button.
  final VoidCallback? onUpdate;

  // After the collaboration badge changed it; a quiet refresh keeps the badge on screen.
  final VoidCallback? onCollaborationChanged;

  // Revoking your own membership is not allowed, so the button is hidden.
  final bool isOwnProfile;

  // Rendered under the card, inside the scroll.
  final Widget? footer;

  const PersonMembershipsTab({
    super.key,
    required this.person,
    this.onUpdate,
    this.onCollaborationChanged,
    this.isOwnProfile = false,
    this.footer,
  });

  void _showEditDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'EditMemberships',
      builder: (context) => _EditMembershipsDialog(person: person, onUpdate: onUpdate!),
    );
  }

  Future<void> _showReEnrollDialog(BuildContext context) async
  {
    final String? saved = await showBlurredDialog<String>(
      context: context,
      barrierLabel: 'ReEnrollPerson',
      builder: (context) => PersonEditDialog.reEnroll(person: person),
    );

    if (saved != null)
    {
      onUpdate!();
    }
  }

  void _showRevokeDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'RevokeMembership',
      builder: (context) => RevokeMembershipDialog(person: person, onUpdate: onUpdate!),
    );
  }

  // Null when there is nothing to act on: a revoked membership is frozen.
  Widget? _buildActions(BuildContext context, {required bool isRevoked, required bool hasAny})
  {
    // The revoked record offers its cessation form again, to the administrator only.
    if (onUpdate != null && isRevoked)
    {
      return _CessationFormButton(person: person);
    }

    if (onUpdate == null || isRevoked || !hasAny)
    {
      return null;
    }

    final Widget edit = AppGradientButton(
      label: tr('MODIFICA ISCRIZIONI', 'EDIT ENROLMENTS'),
      icon: Icons.edit_rounded,
      onPressed: () => _showEditDialog(context),
    );

    // The year in course is missing: lapsed, or still in January's renewal window.
    final int year = romeNow().year;
    final bool renewable = !(person.memberships ?? const <MembershipItem>[])
        .any((membership) => membership.year >= year);

    // Only a running membership can be revoked.
    final bool revocable = !isOwnProfile && person.isEnrolled;

    if (!renewable && !revocable)
    {
      return edit;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        if (renewable)
          AppGradientButton(
            label: tr('RINNOVA ISCRIZIONE', 'RENEW ENROLMENT'),
            icon: Icons.autorenew_rounded,
            onPressed: () => _showReEnrollDialog(context),
          ),
        edit,
        if (revocable)
          AppGradientButton(
            label: tr('REVOCA ISCRIZIONE', 'REVOKE ENROLMENT'),
            icon: Icons.gavel_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDangerText,
            onPressed: () => _showRevokeDialog(context),
          ),
      ],
    );
  }

  Widget _buildStatus({required bool isEnrolled, required bool isFemale, required bool dense})
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isEnrolled ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isEnrolled ? AppTheme.trialSeaGreen : AppTheme.trialDangerText,
          size: dense ? 24 : 30,
        ),
        SizedBox(width: dense ? 10 : 12),
        Flexible(
          child: Text(
            membershipStatusLabel(isEnrolled: isEnrolled, isFemale: isFemale),
            style: GoogleFonts.plusJakartaSans(
              fontSize: dense ? 19 : 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialOceanText,
            ),
          ),
        ),
      ],
    );
  }

  // Only the administrator's editable view shows the collaboration.
  Widget? _buildBadge({required bool isEnrolled, required bool isRevoked, required bool isFemale})
  {
    if (onUpdate == null)
    {
      return null;
    }

    final bool locked = isRevoked || !isEnrolled;

    return SelectionContainer.disabled(
      child: CollaborationBadge(
        person: person,
        // Collaboration only counts while the membership is running.
        isActive: isEnrolled && (person.isActiveCollaborator ?? false),
        lockedTip: locked
            ? collaborationLockedTip(isRevoked: isRevoked, isFemale: isFemale)
            : null,
        onChanged: onCollaborationChanged ?? onUpdate,
      ),
    );
  }

  // Without buttons the status sits in the middle of the card.
  Widget _buildHeader(BuildContext context, MembershipItem? latest)
  {
    final bool isRevoked = latest != null && latest.isRevoked;
    final bool isEnrolled = person.isEnrolled;
    final bool isFemale = person.gender == 'F';
    final bool dense = AppPageDensity.of(context);
    final double height = dense ? _denseHeaderHeight : _headerHeight;
    final double gap = dense ? _denseHeaderGap : _headerGap;

    final List<Widget> status = [
      _buildStatus(isEnrolled: isEnrolled, isFemale: isFemale, dense: dense),
      ?_buildBadge(isEnrolled: isEnrolled, isRevoked: isRevoked, isFemale: isFemale),
      if (latest != null && latest.isRevoked) _RevokedNotice(text: revokedMembershipLabel(latest)),
    ];

    final Widget? actions = _buildActions(context, isRevoked: isRevoked, hasAny: latest != null);

    if (actions == null)
    {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: gap,
            runSpacing: 12,
            children: status,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: gap,
        runSpacing: 16,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: gap,
            runSpacing: 12,
            children: status,
          ),
          SelectionContainer.disabled(child: actions),
        ],
      ),
    );
  }

  Widget _buildEyebrow(String text, bool dense)
  {
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 8 : 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: dense ? 1.5 : 1.6,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }

  Widget _buildCurrent(MembershipItem membership, bool dense)
  {
    final deadline = membership.renewalDeadline;

    final List<(String, String, bool)> facts = [
      (tr('Anno', 'Year'), '${membership.year}', true),
      (tr('Data inizio', 'Start date'), _dateFormat.format(membership.startDate), false),
      (tr('Data fine', 'End date'), _dateFormat.format(membership.endDate), false),
      (tr('Rinnovo entro', 'Renew by'), _dateFormat.format(deadline), false),
    ];

    TextStyle label() => _labelStyle(dense ? 12.5 : 14);
    TextStyle value(bool strong) => _valueStyle(dense ? (strong ? 17 : 15.5) : (strong ? 20 : 18), strong: strong);

    Widget fact((String, String, bool) item)
    {
      final (String name, String text, bool strong) = item;

      return Expanded(
        child: Column(
          children: [
            WholeWords(child: Text(name, textAlign: TextAlign.center, style: label())),
            SizedBox(height: dense ? 3 : 5),
            WholeWords(child: Text(text, textAlign: TextAlign.center, style: value(strong))),
          ],
        ),
      );
    }

    Widget row(List<(String, String, bool)> items)
    {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final item in items) fact(item)]);
    }

    final double paddingH = dense ? _denseCurrentPaddingH : _currentPaddingH;
    final double paddingV = dense ? _denseCurrentPaddingV : _currentPaddingV;

    return TodayFrame(
      radius: dense ? _denseRowRadius : _rowRadius,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: paddingH - TodayFrame.rim,
          vertical: paddingV - TodayFrame.rim,
        ),
        child: !dense
            ? row(facts)
            : LayoutBuilder(
                builder: (context, constraints)
                {
                  // Two by two where a date would break in a quarter of the row.
                  double widest = 0;

                  for (final (name, text, strong) in facts)
                  {
                    widest = [widest, _textWidth(context, name, label()), _textWidth(context, text, value(strong))]
                        .reduce((a, b) => a > b ? a : b);
                  }

                  if (constraints.maxWidth >= 4 * (widest + _denseCurrentPaddingH))
                  {
                    return row(facts);
                  }

                  return Column(
                    children: [
                      row(facts.sublist(0, 2)),
                      const SizedBox(height: _denseGridGap),
                      row(facts.sublist(2)),
                    ],
                  );
                },
              ),
      ),
    );
  }

  double _textWidth(BuildContext context, String text, TextStyle style)
  {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final double width = painter.width;
    painter.dispose();

    return width;
  }

  Widget _buildPastTable(List<MembershipItem> past, bool dense)
  {
    final double radius = dense ? _denseRowRadius : _rowRadius;
    final double paddingH = dense ? _denseTablePaddingH : _tablePaddingH;
    final double value = dense ? 14.5 : 17;
    final TextStyle head = _labelStyle(dense ? 12 : 13);

    Widget cell(Widget child) => Expanded(child: Center(child: child));

    Widget row(MembershipItem membership, {required bool first})
    {
      final bool revoked = membership.isRevoked;
      final Color? tint = revoked ? AppTheme.trialDangerText : null;

      return Container(
        height: dense ? _denseTableRowHeight : _tableRowHeight,
        color: revoked ? _revokedRowSurface : null,
        padding: EdgeInsets.symmetric(horizontal: paddingH - _tableBorder),
        child: Stack(
          children: [
            if (!first)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Divider(height: 1, thickness: 1, color: _tableRule),
              ),
            Row(
              children: [
                cell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (revoked) ...[
                        AppTooltip(
                          message: revokedMembershipLabel(membership),
                          child: Icon(Icons.gavel_rounded, size: dense ? 15 : 17, color: AppTheme.trialDangerText),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text('${membership.year}', style: _valueStyle(value, strong: true, color: tint)),
                      ),
                    ],
                  ),
                ),
                cell(WholeWords(child: Text(_dateFormat.format(membership.startDate), style: _valueStyle(value, color: tint)))),
                cell(WholeWords(child: Text(_dateFormat.format(membership.endDate), style: _valueStyle(value, color: tint)))),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.trialLine, width: _tableBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - _tableBorder),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: dense ? _denseTableHeadHeight : _tableHeadHeight,
              padding: EdgeInsets.symmetric(horizontal: paddingH - _tableBorder),
              decoration: BoxDecoration(
                color: _tableHeadSurface,
                border: Border(bottom: BorderSide(color: AppTheme.trialLine)),
              ),
              child: Row(
                children: [
                  cell(Text(tr('Anno', 'Year'), style: head)),
                  cell(Text(tr('Data inizio', 'Start date'), style: head)),
                  cell(Text(tr('Data fine', 'End date'), style: head)),
                ],
              ),
            ),
            for (var i = 0; i < past.length; i++) row(past[i], first: i == 0),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final memberships = [...?person.memberships];
    memberships.sort((a, b) => b.year.compareTo(a.year));

    final latest = memberships.isNotEmpty ? memberships.first : null;

    // Only the most recent membership can be the running one.
    final currentMembership = person.isEnrolled ? latest : null;
    final pastMemberships = person.isEnrolled ? memberships.skip(1).toList() : memberships;

    final bool dense = AppPageDensity.of(context);

    final Widget card = Container(
      padding: dense ? _denseCardPadding : const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(dense ? _denseCardRadius : _cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SelectionArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, latest),
            Padding(
              padding: EdgeInsets.symmetric(vertical: dense ? _denseRuleSpace : 20),
              child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
            ),
            if (currentMembership != null) ...[
              _buildEyebrow(tr('Iscrizione attuale', 'Current enrolment'), dense),
              _buildCurrent(currentMembership, dense),
              if (pastMemberships.isNotEmpty) SizedBox(height: dense ? 18 : 24),
            ],
            if (pastMemberships.isNotEmpty) ...[
              _buildEyebrow(tr('Iscrizioni passate', 'Past enrolments'), dense),
              _buildPastTable(pastMemberships, dense),
            ],
            if (latest == null) PersonEmptyState(message: kNoMembershipsMessage),
          ],
        ),
      ),
    );

    return ScrollEdgeFade(
      child: TransitionScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _cardsWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pageTransitionBlocks([
                card,
                if (footer != null) ...[
                  SizedBox(height: personSectionGap(context)),
                  footer!,
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevokedNotice extends StatelessWidget
{
  final String text;

  const _RevokedNotice({required this.text});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _revokedSurface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel_rounded, size: 18, color: AppTheme.trialDangerText),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialDangerText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _CessationFormButton extends StatefulWidget
{
  final PersonItem person;

  const _CessationFormButton({required this.person});

  @override
  State<_CessationFormButton> createState() => _CessationFormButtonState();
}

class _CessationFormButtonState extends State<_CessationFormButton>
{
  bool _isGenerating = false;

  Future<void> _open() async
  {
    if (_isGenerating)
    {
      return;
    }

    final PersonItem person = widget.person;
    final PdfTab? tab = openCessationFormTab(person);

    setState(() => _isGenerating = true);

    try
    {
      // Dated as the revocation: the day the membership ended.
      final DateTime day = person.latestMembership?.endDate ?? romeNow();

      if (await presentCessationForm(person, tab, day: day) && mounted)
      {
        CustomSnackBar.show(context: context, message: kCessationFormBlocked, isError: false);
      }
    }
    catch (e)
    {
      tab?.fail(kCessationFormFailed);

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return AppGradientButton(
      label: tr('MODULO DI CESSAZIONE', 'LEAVING FORM'),
      icon: Icons.picture_as_pdf_outlined,
      busy: _isGenerating,
      onPressed: _open,
    );
  }
}

class _MembershipRowData
{
  final TextEditingController yearController;
  final TextEditingController dayMonthController;

  // Carried through untouched: only the dedicated revoke dialog can change it.
  final String revocation;

  // Preserved so saving does not silently reset it.
  final int renewalPeriodDays;

  // Held by payments: see MembershipItem.
  final bool locked;
  final DateTime? latestStart;

  _MembershipRowData({
    required this.yearController,
    required this.dayMonthController,
    required this.revocation,
    required this.renewalPeriodDays,
    this.locked = false,
    this.latestStart,
  });

  void dispose()
  {
    yearController.dispose();
    dayMonthController.dispose();
  }
}

class _EditMembershipsDialog extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const _EditMembershipsDialog({required this.person, required this.onUpdate});

  @override
  State<_EditMembershipsDialog> createState() => _EditMembershipsDialogState();
}

class _EditMembershipsDialogState extends State<_EditMembershipsDialog>
{
  final ApiService _apiService = ApiService();
  final List<_MembershipRowData> _rows = [];
  final Map<String, String> _errors = {};

  bool _isSaving = false;

  // A newer year comes only through «RINNOVA ISCRIZIONE».
  int? get _newestSaved => newestMembershipYear(widget.person);

  @override
  void initState()
  {
    super.initState();

    for (final membership in widget.person.memberships ?? <MembershipItem>[])
    {
      _rows.add(_MembershipRowData(
        yearController: TextEditingController(text: membership.year.toString()),
        dayMonthController:
            TextEditingController(text: _dayMonthFormat.format(membership.startDate)),
        revocation: membership.revocation,
        renewalPeriodDays: membership.renewalPeriodDays,
        locked: membership.locked,
        latestStart: membership.latestStart,
      ));
    }
  }

  @override
  void dispose()
  {
    for (final row in _rows)
    {
      row.dispose();
    }

    super.dispose();
  }

  void _addEmptyRow()
  {
    int? earliestYear;

    for (final row in _rows)
    {
      final year = int.tryParse(row.yearController.text.trim());

      if (year != null && (earliestYear == null || year < earliestYear))
      {
        earliestYear = year;
      }
    }

    setState(()
    {
      // New rows go back in time: the year before the oldest already written.
      final int year = earliestYear == null ? romeNow().year : earliestYear - 1;

      _rows.add(_MembershipRowData(
        yearController: TextEditingController(text: year.toString()),
        dayMonthController: TextEditingController(),
        revocation: MembershipItem.revocationNone,
        // The dialog has no field for it, so new rows get the standard.
        renewalPeriodDays: MembershipItem.defaultRenewalPeriodDays,
      ));
    });
  }

  void _removeRow(int index)
  {
    setState(() => _rows.removeAt(index).dispose());
  }

  bool _isRealDate(String dayMonth, String year)
  {
    final parts = dayMonth.split('/');

    if (parts.length != 2)
    {
      return false;
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final parsedYear = int.tryParse(year);

    if (day == null || month == null || parsedYear == null)
    {
      return false;
    }

    // DateTime rolls over invalid values (31/02 becomes 02/03), so compare the components back.
    final date = DateTime(parsedYear, month, day);

    return date.year == parsedYear && date.month == month && date.day == day;
  }

  // Each row is checked independently so one bad year does not hide the rest.
  bool _validateRows()
  {
    _errors.clear();

    final seenYears = <int>{};

    for (var i = 0; i < _rows.length; i++)
    {
      final row = _rows[i];
      final yearText = row.yearController.text.trim();
      final dayMonthText = row.dayMonthController.text.trim();

      var isYearValid = false;

      if (!RegExp(r'^\d{4}$').hasMatch(yearText))
      {
        _errors['year_$i'] = tr('Anno non valido', 'Invalid year');
      }
      else if (!seenYears.add(int.parse(yearText)))
      {
        _errors['year_$i'] = tr('Anno già inserito', 'Year already entered');
      }
      else if (_newestSaved != null && int.parse(yearText) > _newestSaved!)
      {
        _errors['year_$i'] = kNewYearError;
      }
      else
      {
        isYearValid = true;
      }

      if (dayMonthText.isEmpty)
      {
        _errors['start_$i'] = tr('Campo obbligatorio', 'Required field');
      }
      else if (isYearValid && !_isRealDate(dayMonthText, yearText))
      {
        _errors['start_$i'] = tr('Data non valida', 'Invalid date');
      }
      else if (!isYearValid && !RegExp(r'^\d{2}/\d{2}$').hasMatch(dayMonthText))
      {
        _errors['start_$i'] = tr('Formato gg/mm', 'Format dd/mm');
      }
      else if (isYearValid)
      {
        final String? pastPayments =
            MembershipEditRow.startPastPayments(row.latestStart, dayMonthText, yearText);

        if (pastPayments != null)
        {
          _errors['start_$i'] = pastPayments;
        }
      }
    }

    return _errors.isEmpty;
  }

  // A membership always ends on the last day of its own year.
  List<Map<String, dynamic>> _buildPayload()
  {
    final payload = _rows.map((row)
    {
      final year = row.yearController.text.trim();
      final parts = row.dayMonthController.text.trim().split('/');

      return <String, dynamic>{
        'year': int.parse(year),
        'start_date': '$year-${parts[1]}-${parts[0]}',
        'end_date': '$year-12-31',
        'renewal_period_days': row.renewalPeriodDays,
        'revocation': row.revocation,
      };
    }).toList();

    payload.sort((a, b) => (b['year'] as int).compareTo(a['year'] as int));

    return payload;
  }

  Future<void> _save() async
  {
    if (_rows.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: tr("Deve esserci almeno un'iscrizione.", 'There must be at least one enrolment.'),
        isError: true,
      );

      return;
    }

    if (!_validateRows())
    {
      setState(() {});
      CustomSnackBar.show(
        context: context,
        message: tr('Correggi gli errori prima di salvare.', 'Fix the errors before saving.'),
        isError: true,
      );

      return;
    }

    final payload = _buildPayload();

    setState(() => _isSaving = true);

    try
    {
      try
      {
        await _apiService.updatePersonMemberships(
          widget.person.fiscalCode,
          payload,
          widget.person.memberUpdatedAt,
        );
      }
      on WriteWouldTakeAway catch (refusal)
      {
        if (!mounted)
        {
          return;
        }

        // No spinner behind the question: nothing is being saved meanwhile.
        setState(() => _isSaving = false);

        if (!await confirmPersonLosses(context, refusal, eyebrow: tr('Iscrizioni', 'Enrolments')) || !mounted)
        {
          return;
        }

        setState(() => _isSaving = true);

        await _apiService.updatePersonMemberships(
          widget.person.fiscalCode,
          payload,
          widget.person.memberUpdatedAt,
          confirm: true,
        );
      }

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: tr('Iscrizioni aggiornate con successo!', 'Enrolments updated successfully!'),
          isError: false,
        );

        Navigator.of(context).pop();
        widget.onUpdate();
      }
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: tr('Iscrizioni', 'Enrolments'),
      title: tr('Modifica iscrizioni', 'Edit enrolments'),
      maxWidth: 720,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: tr('SALVA', 'SAVE'),
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _save,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppFieldLabel(tr('Storico iscrizioni', 'Enrolment history')),
              const SizedBox(height: 12),
              CardScrollArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _rows.length; i++)
                      MembershipEditRow(
                        yearController: _rows[i].yearController,
                        dayMonthController: _rows[i].dayMonthController,
                        yearError: _errors['year_$i'],
                        startError: _errors['start_$i'],
                        onYearChanged: (_) => setState(() => _errors.remove('year_$i')),
                        onDayMonthChanged: (_) =>
                            setState(() => _errors.remove('start_$i')),
                        onRemove: () => _removeRow(i),
                        locked: _rows[i].locked,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              AppAddRowButton(label: tr('AGGIUNGI ISCRIZIONE', 'ADD ENROLMENT'), onTap: _addEmptyRow),
            ],
          ),
        ),
      ],
    );
  }
}
