import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/card_scroll_area.dart';
import '../../association/tabs/opening_hours/hours_grid.dart' show TodayFrame;
import '../models/membership_item.dart';
import '../models/person_item.dart';
import '../widgets/collaboration_badge.dart';
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

const Color _revokedSurface = Color(0xFFFBEDEA);
const Color _revokedRowSurface = Color(0xFFFDF4F2);
const Color _tableHeadSurface = Color(0xFFF5F8F8);
const Color _tableRule = Color(0xFFEDF2F1);

const Map<String, String> _revocationLabels = {
  MembershipItem.revocationExpulsion: 'Espulsione',
  MembershipItem.revocationResignation: 'Dimissioni',
};

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
final DateFormat _dayMonthFormat = DateFormat('dd/MM');

const String kNoMembershipsMessage = 'Nessuna iscrizione registrata.';

String membershipStatusLabel({required bool isEnrolled, required bool isFemale})
{
  return isEnrolled
      ? (isFemale ? 'Iscritta' : 'Iscritto')
      : (isFemale ? 'Non iscritta' : 'Non iscritto');
}

String revokedMembershipLabel(MembershipItem membership)
{
  return 'Iscrizione revocata (${_revocationLabels[membership.revocation] ?? membership.revocation})';
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
    color: color ?? (strong ? AppTheme.trialOcean : AppTheme.trialInk),
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

  void _showRevokeDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'RevokeMembership',
      builder: (context) => _RevokeMembershipDialog(person: person, onUpdate: onUpdate!),
    );
  }

  // Null when there is nothing to act on: a revoked membership is frozen.
  Widget? _buildActions(BuildContext context, {required bool isRevoked, required bool hasAny})
  {
    if (onUpdate == null || isRevoked || !hasAny)
    {
      return null;
    }

    final Widget edit = AppGradientButton(
      label: 'MODIFICA ISCRIZIONI',
      icon: Icons.edit_rounded,
      onPressed: () => _showEditDialog(context),
    );

    // Only a running membership can be revoked.
    if (isOwnProfile || !person.isEnrolled)
    {
      return edit;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        edit,
        AppGradientButton(
          label: 'REVOCA ISCRIZIONE',
          icon: Icons.gavel_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
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
          color: isEnrolled ? AppTheme.trialSeaGreen : AppTheme.trialDanger,
          size: dense ? 24 : 30,
        ),
        SizedBox(width: dense ? 10 : 12),
        Flexible(
          child: Text(
            membershipStatusLabel(isEnrolled: isEnrolled, isFemale: isFemale),
            style: GoogleFonts.plusJakartaSans(
              fontSize: dense ? 19 : 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialOcean,
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
      ('Anno', '${membership.year}', true),
      ('Data inizio', _dateFormat.format(membership.startDate), false),
      ('Data fine', _dateFormat.format(membership.endDate), false),
      ('Rinnovo entro', _dateFormat.format(deadline), false),
    ];

    TextStyle label() => _labelStyle(dense ? 12.5 : 14);
    TextStyle value(bool strong) => _valueStyle(dense ? (strong ? 17 : 15.5) : (strong ? 20 : 18), strong: strong);

    Widget fact((String, String, bool) item)
    {
      final (String name, String text, bool strong) = item;

      return Expanded(
        child: Column(
          children: [
            Text(name, textAlign: TextAlign.center, style: label()),
            SizedBox(height: dense ? 3 : 5),
            Text(text, textAlign: TextAlign.center, style: value(strong)),
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
      final Color? tint = revoked ? AppTheme.trialDanger : null;

      return Container(
        height: dense ? _denseTableRowHeight : _tableRowHeight,
        color: revoked ? _revokedRowSurface : null,
        padding: EdgeInsets.symmetric(horizontal: paddingH - _tableBorder),
        child: Stack(
          children: [
            if (!first)
              const Positioned(
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
                          child: Icon(Icons.gavel_rounded, size: dense ? 15 : 17, color: AppTheme.trialDanger),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text('${membership.year}', style: _valueStyle(value, strong: true, color: tint)),
                      ),
                    ],
                  ),
                ),
                cell(Text(_dateFormat.format(membership.startDate), style: _valueStyle(value, color: tint))),
                cell(Text(_dateFormat.format(membership.endDate), style: _valueStyle(value, color: tint))),
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
              decoration: const BoxDecoration(
                color: _tableHeadSurface,
                border: Border(bottom: BorderSide(color: AppTheme.trialLine)),
              ),
              child: Row(
                children: [
                  cell(Text('Anno', style: head)),
                  cell(Text('Data inizio', style: head)),
                  cell(Text('Data fine', style: head)),
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
        color: Colors.white,
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
              child: const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
            ),
            if (currentMembership != null) ...[
              _buildEyebrow('Iscrizione attuale', dense),
              _buildCurrent(currentMembership, dense),
              if (pastMemberships.isNotEmpty) SizedBox(height: dense ? 18 : 24),
            ],
            if (pastMemberships.isNotEmpty) ...[
              _buildEyebrow('Iscrizioni passate', dense),
              _buildPastTable(pastMemberships, dense),
            ],
            if (latest == null) const PersonEmptyState(message: kNoMembershipsMessage),
          ],
        ),
      ),
    );

    return ScrollEdgeFade(
      child: SingleChildScrollView(
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
          const Icon(Icons.gavel_rounded, size: 18, color: AppTheme.trialDanger),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialDanger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _RevokeMembershipDialog extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const _RevokeMembershipDialog({required this.person, required this.onUpdate});

  @override
  State<_RevokeMembershipDialog> createState() => _RevokeMembershipDialogState();
}

class _RevokeMembershipDialogState extends State<_RevokeMembershipDialog>
{
  final ApiService _apiService = ApiService();

  String _selectedCode = MembershipItem.revocationResignation;
  bool _isSaving = false;

  Future<void> _submitRevocation() async
  {
    setState(() => _isSaving = true);

    try
    {
      // memberUpdatedAt is the optimistic concurrency token.
      await _apiService.revokePersonMembership(
        widget.person.fiscalCode,
        _selectedCode,
        widget.person.memberUpdatedAt,
      );

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Iscrizione revocata con successo.',
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

  Widget _buildWarning()
  {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _revokedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: AppTheme.trialDanger, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "L'operazione è irreversibile: l'iscrizione terminerà in data odierna "
              'e lo stato di collaborazione verrà disattivato.'
              "${widget.person.hasAccount ? " L'account verrà sospeso definitivamente." : ''}",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialDanger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Iscrizione',
      title: 'Revoca iscrizione',
      maxWidth: 560,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'CONFERMA REVOCA',
          icon: Icons.gavel_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          busy: _isSaving,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _submitRevocation,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWarning(),
              const SizedBox(height: 22),
              const AppFieldLabel('Motivazione della revoca'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in _revocationLabels.entries)
                    AppSelectableChip(
                      label: entry.value,
                      selected: _selectedCode == entry.key,
                      onSelected: (selected) => setState(()
                      {
                        if (selected)
                        {
                          _selectedCode = entry.key;
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
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

  _MembershipRowData({
    required this.yearController,
    required this.dayMonthController,
    required this.revocation,
    required this.renewalPeriodDays,
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
        _errors['year_$i'] = 'Anno non valido';
      }
      else if (!seenYears.add(int.parse(yearText)))
      {
        _errors['year_$i'] = 'Anno già inserito';
      }
      else
      {
        isYearValid = true;
      }

      if (dayMonthText.isEmpty)
      {
        _errors['start_$i'] = 'Campo obbligatorio';
      }
      else if (isYearValid && !_isRealDate(dayMonthText, yearText))
      {
        _errors['start_$i'] = 'Data non valida';
      }
      else if (!isYearValid && !RegExp(r'^\d{2}/\d{2}$').hasMatch(dayMonthText))
      {
        _errors['start_$i'] = 'Formato gg/mm';
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
        message: "Deve esserci almeno un'iscrizione.",
        isError: true,
      );

      return;
    }

    if (!_validateRows())
    {
      setState(() {});
      CustomSnackBar.show(
        context: context,
        message: 'Correggi gli errori prima di salvare.',
        isError: true,
      );

      return;
    }

    final payload = _buildPayload();

    setState(() => _isSaving = true);

    try
    {
      await _apiService.updatePersonMemberships(
        widget.person.fiscalCode,
        payload,
        widget.person.memberUpdatedAt,
      );

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Iscrizioni aggiornate con successo!',
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
      eyebrow: 'Iscrizioni',
      title: 'Modifica iscrizioni',
      maxWidth: 720,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'SALVA',
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
              const AppFieldLabel('Storico iscrizioni'),
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
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              AppAddRowButton(label: 'AGGIUNGI ISCRIZIONE', onTap: _addEmptyRow),
            ],
          ),
        ),
      ],
    );
  }
}
