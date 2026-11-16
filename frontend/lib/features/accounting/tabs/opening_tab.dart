import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/alphabetical_order.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../people/edit/person_edit_form.dart' show kCollaborationTypes;
import '../../people/tabs/person_account_shared.dart' show askPersonConfirmation;
import '../../people/widgets/person_card.dart';
import '../models/opening_items.dart';
import '../utils/opening_strings.dart';
import '../widgets/opening_dialogs.dart';
import '../widgets/opening_person_card.dart';

const int _maxColumns = 4;
const double _cardGap = 16;
const double _closeWidth = 330;
const double _closeHeight = 52;
const double _closeRoom = _closeHeight + 40;

enum OpeningSide { teachers, pupils }

// One side of the initial set-up: who is still to set up, or who is confirmed, to correct.
class OpeningTab extends StatefulWidget
{
  final OpeningSide side;
  final AccountingOpening opening;
  final ValueChanged<AccountingOpening> onChanged;

  const OpeningTab({super.key, required this.side, required this.opening, required this.onChanged});

  @override
  State<OpeningTab> createState() => _OpeningTabState();
}

class _OpeningTabState extends State<OpeningTab>
{
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _confirmedView = false;
  bool _closing = false;

  bool get _teachers => widget.side == OpeningSide.teachers;

  @override
  void dispose()
  {
    _search.dispose();
    super.dispose();
  }

  String _tagOfTeacher(OpeningTeacher teacher)
  {
    final int? rate = teacher.grossRateCents;

    if (teacher.missing)
    {
      return kPayMissing;
    }

    if (teacher.isPaid && rate != null)
    {
      return paidTag(rate);
    }

    return kCollaborationTypes.entries
            .where((entry) => entry.value == teacher.collaborationType)
            .map((entry) => entry.key)
            .firstOrNull ??
        teacher.collaborationType;
  }

  bool _matches(String name)
  {
    final String query = _query.trim().toLowerCase();

    return query.isEmpty || name.toLowerCase().contains(query);
  }

  Future<void> _openTeacher(OpeningTeacher teacher) async
  {
    final OpeningTeacher? saved = await showTeacherOpeningDialog(
      context: context,
      teacher: teacher,
      lastDay: widget.opening.lastDay,
    );

    if (saved == null || !mounted)
    {
      return;
    }

    widget.onChanged(widget.opening.withTeacher(saved));
    CustomSnackBar.show(context: context, message: kTeacherConfirmed);
  }

  Future<void> _openPupil(OpeningPupil pupil) async
  {
    final OpeningPupil? saved = await showPupilOpeningDialog(
      context: context,
      pupil: pupil,
      lastDay: widget.opening.lastDay,
    );

    if (saved == null || !mounted)
    {
      return;
    }

    widget.onChanged(widget.opening.withPupil(saved));
    CustomSnackBar.show(context: context, message: kPupilConfirmed);
  }

  Future<void> _close() async
  {
    final bool confirmed = await askPersonConfirmation(
      context,
      eyebrow: kOpeningEyebrow,
      message: [TextSpan(text: closeOpeningMessage(widget.opening.lastDay))],
      confirmLabel: kCloseLabel,
      confirmIcon: Icons.check_rounded,
      danger: false,
    );

    if (!confirmed || !mounted)
    {
      return;
    }

    setState(() => _closing = true);

    try
    {
      final AccountingOpening closed = await ApiService().closeAccountingOpening();

      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(context: context, message: kOpeningClosed);
      widget.onChanged(closed);
    }
    catch (error)
    {
      if (mounted)
      {
        setState(() => _closing = false);
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
  }

  Widget _intro(bool dense)
  {
    final AccountingOpening opening = widget.opening;
    final int all = _teachers ? opening.teachers.length : opening.pupils.length;
    final int done = all - (_teachers ? opening.teachersLeft : opening.pupilsLeft);
    final TextStyle plain = GoogleFonts.plusJakartaSans(
      fontSize: dense ? 13.5 : 15,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: AppTheme.trialMutedText,
    );

    final Widget progress = SizedBox(
      width: dense ? 200 : 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                confirmedOf(done, all),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: dense ? 16 : 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trialOcean,
                ),
              ),
              const Spacer(),
              Text(kConfirmedWord, style: plain.copyWith(fontSize: dense ? 12.5 : 13.5, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Color(0xFFE6EEEE))),
                  FractionallySizedBox(
                    widthFactor: all == 0 ? 1 : done / all,
                    heightFactor: 1,
                    child: const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.brandGradient)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 20 : 28, vertical: dense ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(dense ? 22 : 28),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  for (final (text, bold) in _teachers
                      ? teachersIntro(opening.lastDay)
                      : pupilsIntro(opening.lastDay))
                    TextSpan(
                      text: text,
                      style: bold ? const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.trialOcean) : null,
                    ),
                ],
              ),
              style: plain,
            ),
          ),
          SizedBox(width: dense ? 24 : 40),
          progress,
        ],
      ),
    );
  }

  Widget _tools()
  {
    return Row(
      children: [
        AppSegmentedSwitch(
          value: !_confirmedView,
          trueLabel: kToSetUpChoice,
          falseLabel: kConfirmedChoice,
          hugContent: true,
          onChanged: (value) => setState(() => _confirmedView = !value),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AppSearchField(
            controller: _search,
            hintText: _teachers ? kSearchTeacherHint : kSearchPupilHint,
            onChanged: (text) => setState(() => _query = text),
          ),
        ),
      ],
    );
  }

  List<Widget> _cards(double width)
  {
    if (_teachers)
    {
      final List<OpeningTeacher> shown = [
        for (final teacher in widget.opening.teachers)
          if (teacher.confirmed == _confirmedView && _matches(teacher.fullName)) teacher,
      ]..sort((a, b) => compareAlphabeticallyInParts([a.firstName, a.lastName], [b.firstName, b.lastName]));

      return [
        for (final teacher in shown)
          OpeningPersonCard(
            firstName: teacher.firstName,
            lastName: teacher.lastName,
            photoUrl: teacher.profileImageUrl,
            tag: _tagOfTeacher(teacher),
            missing: teacher.missing,
            confirmed: teacher.confirmed,
            width: width,
            onTap: () => _openTeacher(teacher),
          ),
      ];
    }

    final List<OpeningPupil> shown = [
      for (final pupil in widget.opening.pupils)
        if (pupil.confirmed == _confirmedView && _matches(pupil.fullName)) pupil,
    ]..sort((a, b) => compareAlphabeticallyInParts([a.firstName, a.lastName], [b.firstName, b.lastName]));

    return [
      for (final pupil in shown)
        OpeningPersonCard(
          firstName: pupil.firstName,
          lastName: pupil.lastName,
          photoUrl: pupil.profileImageUrl,
          tag: pupil.tariff == null
              ? kTariffMissing
              : tariffTag(pupil.tariff!.kind, pupil.tariff!.amountCents, pupil.tariff!.packageHours),
          missing: pupil.tariff == null,
          confirmed: pupil.confirmed,
          width: width,
          onTap: () => _openPupil(pupil),
        ),
    ];
  }

  bool get _anyShown => _teachers
      ? widget.opening.teachers.any((row) => row.confirmed == _confirmedView)
      : widget.opening.pupils.any((row) => row.confirmed == _confirmedView);

  String get _found
  {
    final int count = _teachers
        ? widget.opening.teachers.where((row) => row.confirmed == _confirmedView).length
        : widget.opening.pupils.where((row) => row.confirmed == _confirmedView).length;

    if (_teachers)
    {
      return _confirmedView ? teachersConfirmed(count) : teachersToSetUp(count);
    }

    return _confirmedView ? pupilsConfirmed(count) : pupilsToSetUp(count);
  }

  String get _emptyMessage
  {
    final bool any = _teachers
        ? widget.opening.teachers.any((row) => row.confirmed == _confirmedView)
        : widget.opening.pupils.any((row) => row.confirmed == _confirmedView);

    if (any)
    {
      return _teachers ? kNoTeacherFound : kNoPupilFound;
    }

    if (_confirmedView)
    {
      return _teachers ? kNoTeacherConfirmed : kNoPupilConfirmed;
    }

    return _teachers ? kAllTeachersSetUp : kAllPupilsSetUp;
  }

  int _columnsFor(double available)
  {
    for (var columns = _maxColumns; columns > 1; columns--)
    {
      if (columns * PersonCard.minWidth + _cardGap * (columns - 1) <= available)
      {
        return columns;
      }
    }

    return 1;
  }

  Widget _grid(bool closable)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double available = constraints.maxWidth;
        final bool dense = AppBreakpoints.of(context).isDense;
        final denseLayout = EntityCardGrid.denseLayout(available, kDenseWideCardWidth);
        final int columns = _columnsFor(available);
        final double width = dense
            ? denseLayout.width
            : ((available - _cardGap * (columns - 1)) / columns).clamp(PersonCard.minWidth, PersonCard.maxWidth);
        final int fitting = dense ? denseLayout.perRow : ((available + _cardGap) / (width + _cardGap)).floor();
        final List<Widget> cards = _cards(width);

        if (cards.isEmpty)
        {
          return AppEmptyRoom(card: AppEmptyCard(icon: Icons.task_alt_rounded, message: _emptyMessage));
        }

        return PageTransitionScrollView.slivers(
          slivers: [
            CardRows(
              cards: cards,
              cardWidth: width,
              perRow: fitting < 1 ? 1 : fitting,
              gap: dense ? kDenseCardGap : _cardGap,
            ),
            if (closable) const SliverToBoxAdapter(child: SizedBox(height: _closeRoom)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final bool closable = widget.opening.done && !widget.opening.closed;
    final TextStyle muted = GoogleFonts.plusJakartaSans(
      fontSize: dense ? 15 : 17,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );

    final Widget page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(slot: PageTransitionItem.frame, child: _intro(dense)),
        SizedBox(height: dense ? 14 : 20),
        PageTransitionItem(slot: PageTransitionItem.header, child: _tools()),
        SizedBox(height: dense ? 16 : 22),
        // An empty list says so in its card: no count above it.
        if (_anyShown) ...[
          PageTransitionItem(
            slot: PageTransitionItem.header,
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(_found, style: muted),
            ),
          ),
          SizedBox(height: dense ? 10 : 14),
        ],
        Expanded(child: PageTransitionItem(slot: PageTransitionItem.list, child: _grid(closable))),
      ],
    );

    if (!closable)
    {
      return page;
    }

    return Stack(
      children: [
        Positioned.fill(child: page),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x2E0B3350), offset: Offset(0, 10), blurRadius: 28)],
              ),
              child: AppGradientButton(
                label: kCloseOpeningLabel,
                icon: Icons.task_alt_rounded,
                width: _closeWidth,
                height: _closeHeight,
                fontSize: 14,
                busy: _closing,
                onPressed: () => unawaited(_close()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
