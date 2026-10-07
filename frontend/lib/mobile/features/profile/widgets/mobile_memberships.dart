import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/people/models/membership_item.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../../features/people/tabs/person_memberships_tab.dart'
    show kNoMembershipsMessage, membershipStatusLabel, revokedMembershipLabel;
import '../../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_current_card.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import 'mobile_detail_card.dart';

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

// The year column, wide enough for "Anno" and a year.
const double _yearWidth = 54;
const double _columnGap = 10;

// Ring bleed past the text, which keeps the card's left edge; the rim is drawn outside it.
const double _ringBleed = 8;
const double _ringInset = _ringBleed - MobileCurrentCard.rimWidth;
const double _ringTop = MobileCurrentCard.rimWidth;

// Newest first; only the most recent membership can be the running one.
({List<MembershipItem> years, MembershipItem? current}) _membershipsOf(PersonItem person)
{
  final List<MembershipItem> years = [...?person.memberships]
    ..sort((a, b) => b.year.compareTo(a.year));

  return (years: years, current: person.isEnrolled && years.isNotEmpty ? years.first : null);
}

class MobileMembershipStatusCard extends StatelessWidget
{
  final PersonItem person;

  const MobileMembershipStatusCard({super.key, required this.person});

  @override
  Widget build(BuildContext context)
  {
    final bool enrolled = person.isEnrolled;
    final bool female = person.gender == 'F';

    return MobileGlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MobileCardBadge(
              icon: enrolled ? Icons.check_circle_rounded : Icons.cancel_rounded,
              tint: enrolled ? AppTheme.trialSeaGreen : AppTheme.trialDanger,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                membershipStatusLabel(isEnrolled: enrolled, isFemale: female),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trialInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MobileMembershipYearsCard extends StatelessWidget
{
  final PersonItem person;

  const MobileMembershipYearsCard({super.key, required this.person});

  @override
  Widget build(BuildContext context)
  {
    final (:years, :current) = _membershipsOf(person);

    return MobileGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current != null) ...[
            MobileDetailRows(rows: [_renewal(current)]),
            const SizedBox(height: 12),
          ],
          if (years.isEmpty)
            const _NoMemberships()
          else
            _YearsTable(memberships: years, current: current),
        ],
      ),
    );
  }

  static DetailRowData _renewal(MembershipItem membership)
  {
    final DateTime deadline = membership.endDate.add(Duration(days: membership.renewalPeriodDays));

    return DetailRowData('Rinnovo entro', _dateFormat.format(deadline));
  }
}

class _YearsTable extends StatelessWidget
{
  final List<MembershipItem> memberships;
  final MembershipItem? current;

  const _YearsTable({required this.memberships, required this.current});

  Widget _row(BuildContext context, List<Widget> cells)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: MediaQuery.textScalerOf(context).scale(_yearWidth), child: cells[0]),
        const SizedBox(width: _columnGap),
        Expanded(child: cells[1]),
        const SizedBox(width: _columnGap),
        Expanded(child: cells[2]),
      ],
    );
  }

  // A date shrinks rather than wraps when larger text leaves its column narrow.
  Widget _date(DateTime date, TextStyle style)
  {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(_dateFormat.format(date), style: style),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final TextStyle head = mobileFactLabelStyle();
    final TextStyle cell = mobileFactValueStyle().copyWith(fontSize: 15);

    final Color line = AppTheme.trialInk.withValues(alpha: 0.09);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _row(context, [
            Text('Anno', style: head),
            Text('Data inizio', style: head),
            Text('Data fine', style: head),
          ]),
        ),
        for (var i = 0; i < memberships.length; i++)
          _buildYear(
            context,
            memberships[i],
            running: memberships[i] == current,
            // No line against the ringed row, which marks itself.
            ruled: memberships[i] != current && (i == 0 || memberships[i - 1] != current),
            style: cell,
            line: line,
          ),
      ],
    );
  }

  Widget _buildYear(
    BuildContext context,
    MembershipItem membership, {
    required bool running,
    required bool ruled,
    required TextStyle style,
    required Color line,
  })
  {
    final Widget content = Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: ruled ? Border(top: BorderSide(color: line)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(context, [
            Text('${membership.year}', style: style),
            _date(membership.startDate, style),
            _date(membership.endDate, style),
          ]),
          if (membership.isRevoked) ...[
            const SizedBox(height: 6),
            _Revoked(text: revokedMembershipLabel(membership)),
          ],
        ],
      ),
    );

    if (!running)
    {
      return content;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -_ringInset,
          right: -_ringInset,
          top: _ringTop,
          bottom: _ringTop,
          child: DecoratedBox(
            decoration: const MobileCurrentCard(BorderRadius.all(Radius.circular(12 - MobileCurrentCard.rimWidth))),
          ),
        ),
        content,
      ],
    );
  }
}

class _Revoked extends StatelessWidget
{
  final String text;

  const _Revoked({required this.text});

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.gavel_rounded, size: 17, color: AppTheme.trialDanger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.trialDanger,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoMemberships extends StatelessWidget
{
  const _NoMemberships();

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        kNoMembershipsMessage,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: MobilePalette.mutedText,
        ),
      ),
    );
  }
}
