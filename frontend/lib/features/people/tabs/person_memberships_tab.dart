import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/membership_item.dart';
import '../models/person_item.dart';
import '../person_wizard_components.dart';
import '../widgets/person_detail_widgets.dart';

const Color _enrolledColor = Color(0xFF4CAF50);
const Color _notEnrolledColor = Color(0xFFF44336);
const Color _subtleBackground = Color(0xFFF8FAFC);
const Color _strongTextColor = Color(0xFF2A2A2A);

// Values of MembershipItem.revocation as the backend spells them. They travel
// back unchanged in the update payload, so they cannot be translated in place.
const String _revocationNone = 'NO';
const String _revocationExpulsion = 'EXPULSION';
const String _revocationResignation = 'RESIGNATION';

const Map<String, String> _revocationLabels = {
  _revocationExpulsion: 'Espulsione',
  _revocationResignation: 'Dimissioni',
};

// Days after the end date during which the membership can still be renewed. The
// backend stores one per membership, but this dialog can only create new rows and
// has no field for it, so new ones get the standard period.
const int _defaultRenewalPeriodDays = 30;

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
final DateFormat _dayMonthFormat = DateFormat('dd/MM');

/// A membership counts as running until the renewal window after its end date has
/// passed, not on the end date itself.
bool _isWithinRenewalWindow(DateTime endDate, int renewalPeriodDays)
{
  return DateTime.now().isBefore(endDate.add(Duration(days: renewalPeriodDays)));
}

class PersonMembershipsTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  // True when the logged in account is the person being shown. Revoking your own
  // membership is not allowed, so the button is hidden. Defaults to false so
  // other call sites keep working.
  final bool isOwnProfile;

  const PersonMembershipsTab({
    super.key,
    required this.person,
    required this.onUpdate,
    this.isOwnProfile = false,
  });

  void _showEditDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'EditMemberships',
      builder: (context) => _EditMembershipsDialog(person: person, onUpdate: onUpdate),
    );
  }

  void _showRevokeDialog(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'RevokeMembership',
      builder: (context) => _RevokeMembershipDialog(person: person, onUpdate: onUpdate),
    );
  }

  Widget _buildStatusCard({
    required bool isEnrolled,
    required bool isFemale,
    required bool isActiveCollaborator,
  })
  {
    final statusText = isEnrolled
        ? (isFemale ? 'Iscritta' : 'Iscritto')
        : (isFemale ? 'Non iscritta' : 'Non iscritto');

    final collaborationText = isActiveCollaborator
        ? (isFemale ? 'Collaboratrice attiva' : 'Collaboratore attivo')
        : 'Non collaborante';

    return Center(
      child: SelectionArea(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.slate200),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEnrolled ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isEnrolled ? _enrolledColor : _notEnrolledColor,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    statusText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _strongTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _subtleBackground,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActiveCollaborator
                          ? Icons.handshake_outlined
                          : Icons.work_off_rounded,
                      color: isActiveCollaborator ? AppTheme.primary : AppTheme.slate400,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      collaborationText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isActiveCollaborator ? AppTheme.primary : AppTheme.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateItem(String label, String value)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate400,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.slate700,
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipCard(MembershipItem membership, {required bool isCurrent})
  {
    final isRevoked = membership.revocation != _revocationNone;
    final deadline = membership.endDate.add(Duration(days: membership.renewalPeriodDays));

    return SelectionArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 2.0),
        ),
        child: Column(
          children: [
            Text(
              'Anno ${membership.year}',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.slate700,
              ),
            ),
            if (isRevoked) ...[
              const SizedBox(height: 8),
              Text(
                'Iscrizione revocata '
                '(${_revocationLabels[membership.revocation] ?? membership.revocation})',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.danger,
                ),
              ),
            ],
            const SizedBox(height: 32),
            _ResponsiveDateItemsRow(
              items: [
                _buildDateItem('Data inizio', _dateFormat.format(membership.startDate)),
                _buildDateItem('Data fine', _dateFormat.format(membership.endDate)),
                if (isCurrent)
                  _buildDateItem(
                    'Rinnovo entro',
                    isRevoked ? missingValue : _dateFormat.format(deadline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppTheme.primary,
      ),
    );
  }

  Widget _buildActions(BuildContext context)
  {
    if (isOwnProfile)
    {
      return SizedBox(
        width: 240,
        child: AnimatedActionButton(
          text: 'MODIFICA ISCRIZIONI',
          icon: Icons.edit_rounded,
          baseColor: AppTheme.primary,
          hoverColor: AppTheme.primaryHover,
          onPressed: () => _showEditDialog(context),
        ),
      );
    }

    return _ResponsiveActionButtonsRow(
      primaryText: 'MODIFICA ISCRIZIONI',
      primaryIcon: Icons.edit_rounded,
      primaryColor: AppTheme.primary,
      primaryHoverColor: AppTheme.primaryHover,
      primaryOnPressed: () => _showEditDialog(context),
      secondaryText: 'REVOCA ISCRIZIONE',
      secondaryIcon: Icons.gavel_rounded,
      secondaryColor: AppTheme.danger,
      secondaryHoverColor: AppTheme.dangerHover,
      secondaryOnPressed: () => _showRevokeDialog(context),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final memberships = [...?person.memberships];
    memberships.sort((a, b) => b.year.compareTo(a.year));

    final latest = memberships.isNotEmpty ? memberships.first : null;

    final isRevoked = latest != null && latest.revocation != _revocationNone;
    final isEnrolled = latest != null &&
        latest.revocation == _revocationNone &&
        _isWithinRenewalWindow(latest.endDate, latest.renewalPeriodDays);

    // Only the most recent membership can be the running one, so the rest are
    // history whether or not it is.
    final currentMembership = isEnrolled ? latest : null;
    final pastMemberships = isEnrolled ? memberships.skip(1).toList() : memberships;

    final isFemale = person.gender == 'F';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(
            isEnrolled: isEnrolled,
            isFemale: isFemale,
            // Collaboration only counts while the membership is running.
            isActiveCollaborator: isEnrolled && (person.isActiveCollaborator ?? false),
          ),
          const SizedBox(height: 48),
          if (currentMembership != null) ...[
            _buildSectionTitle('Iscrizione attuale'),
            const SizedBox(height: 16),
            _buildMembershipCard(currentMembership, isCurrent: true),
            const SizedBox(height: 32),
          ],
          if (pastMemberships.isNotEmpty) ...[
            _buildSectionTitle('Iscrizioni passate'),
            const SizedBox(height: 16),
            ...pastMemberships.map((membership) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildMembershipCard(membership, isCurrent: false),
                )),
          ],
          if (currentMembership == null && pastMemberships.isEmpty)
            Center(
              child: Text(
                'Nessuna iscrizione registrata.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.slate500,
                ),
              ),
            ),
          if (!isRevoked && latest != null) ...[
            const SizedBox(height: 40),
            Center(child: _buildActions(context)),
          ],
        ],
      ),
    );
  }
}

// Side by side while every item has room, stacked otherwise. The threshold scales
// with the number of items, because two fit in less space than three.
class _ResponsiveDateItemsRow extends StatelessWidget
{
  static const double _minItemWidth = 150;

  final List<Widget> items;

  const _ResponsiveDateItemsRow({required this.items});

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < items.length * _minItemWidth)
        {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                items[i],
              ],
            ],
          );
        }

        // Expanded rather than bare children: without it a long value would
        // overflow the row instead of wrapping inside its own column.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) => Expanded(child: item)).toList(),
        );
      },
    );
  }
}

// Two full page actions, centred at a fixed width and stacked below the
// threshold. Distinct from ResponsiveDialogButtonsRow, which stretches its
// buttons to fill a dialog footer.
class _ResponsiveActionButtonsRow extends StatelessWidget
{
  static const double _buttonWidth = 240;
  static const double _spacing = 24;
  static const double _breakpoint = _buttonWidth * 2 + _spacing + 40;

  final String primaryText;
  final IconData primaryIcon;
  final Color primaryColor;
  final Color primaryHoverColor;
  final VoidCallback primaryOnPressed;

  final String secondaryText;
  final IconData secondaryIcon;
  final Color secondaryColor;
  final Color secondaryHoverColor;
  final VoidCallback secondaryOnPressed;

  const _ResponsiveActionButtonsRow({
    required this.primaryText,
    required this.primaryIcon,
    required this.primaryColor,
    required this.primaryHoverColor,
    required this.primaryOnPressed,
    required this.secondaryText,
    required this.secondaryIcon,
    required this.secondaryColor,
    required this.secondaryHoverColor,
    required this.secondaryOnPressed,
  });

  @override
  Widget build(BuildContext context)
  {
    final primaryButton = SizedBox(
      width: _buttonWidth,
      child: AnimatedActionButton(
        text: primaryText,
        icon: primaryIcon,
        baseColor: primaryColor,
        hoverColor: primaryHoverColor,
        onPressed: primaryOnPressed,
      ),
    );

    final secondaryButton = SizedBox(
      width: _buttonWidth,
      child: AnimatedActionButton(
        text: secondaryText,
        icon: secondaryIcon,
        baseColor: secondaryColor,
        hoverColor: secondaryHoverColor,
        onPressed: secondaryOnPressed,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _breakpoint)
        {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              primaryButton,
              const SizedBox(height: 16),
              secondaryButton,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            primaryButton,
            const SizedBox(width: _spacing),
            secondaryButton,
          ],
        );
      },
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

  String _selectedCode = _revocationResignation;
  bool _isSaving = false;

  Future<void> _submitRevocation() async
  {
    setState(() => _isSaving = true);

    try
    {
      // memberUpdatedAt is the optimistic concurrency token: the server refuses
      // the revocation if somebody else changed the membership meanwhile.
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
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: AppTheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'ATTENZIONE: Questa operazione è irreversibile. '
              "L'iscrizione terminerà in data odierna e lo stato di collaborazione "
              'verrà disattivato.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
                height: 1.3,
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        // Fills the available space but never past 540: without an explicit
        // width the inner buttons never get a constraint tight enough to stack.
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Revoca Iscrizione',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                FadeHoverIconButton(
                  icon: Icons.close,
                  color: AppTheme.primary,
                  hoverColor: AppTheme.iconHover,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 32, thickness: 1, color: AppTheme.divider),
            _buildWarning(),
            const SizedBox(height: 24),
            Text(
              'Seleziona la motivazione della revoca:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            // The dropdown shows the Italian labels while the state keeps the
            // backend code, so no translation is needed on submit.
            _FormOverlayDropdown(
              value: _selectedCode,
              labels: _revocationLabels,
              onSelected: (code) => setState(() => _selectedCode = code),
            ),
            const SizedBox(height: 32),
            ResponsiveDialogButtonsRow(
              stackedButtonWidth: null,
              secondaryButton: AnimatedActionButton(
                text: 'ANNULLA',
                icon: Icons.cancel_outlined,
                baseColor: AppTheme.danger,
                hoverColor: AppTheme.dangerHover,
                onPressed: () => Navigator.of(context).pop(),
              ),
              primaryButton: AnimatedActionButton(
                text: _isSaving ? 'REVOCA...' : 'CONFERMA REVOCA',
                icon: Icons.gavel_rounded,
                baseColor: AppTheme.primary,
                hoverColor: AppTheme.primaryHover,
                onPressed: _isSaving ? () {} : _submitRevocation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipRowData
{
  final TextEditingController yearController;
  final TextEditingController dayMonthController;

  // Carried through untouched: this dialog cannot change a revocation, only the
  // dedicated revoke dialog can.
  final String revocation;

  // Preserved from the loaded membership so that saving does not silently reset
  // it. New rows get the standard period.
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

  late bool _isActiveCollaborator;
  bool _isSaving = false;

  @override
  void initState()
  {
    super.initState();

    _isActiveCollaborator = widget.person.isActiveCollaborator ?? false;

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
    var latestYear = DateTime.now().year;

    for (final row in _rows)
    {
      final year = int.tryParse(row.yearController.text) ?? 0;

      if (year > latestYear)
      {
        latestYear = year;
      }
    }

    setState(()
    {
      // Proposes the year before the most recent one, since rows are added going
      // back in time.
      _rows.add(_MembershipRowData(
        yearController: TextEditingController(text: (latestYear - 1).toString()),
        dayMonthController: TextEditingController(),
        revocation: _revocationNone,
        renewalPeriodDays: _defaultRenewalPeriodDays,
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

    // DateTime rolls over invalid values, so 31/02 becomes 02/03: comparing the
    // components back is what rejects it.
    final date = DateTime(parsedYear, month, day);

    return date.year == parsedYear && date.month == month && date.day == day;
  }

  // Fills _errors and returns whether every row is usable. Each row is checked on
  // its own, so one bad year does not hide the problems of the rows below it.
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

  // The membership always ends on the last day of its own year, so only the start
  // day and month are editable.
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

  bool _hasRunningMembership(List<Map<String, dynamic>> payload)
  {
    for (final membership in payload)
    {
      if (membership['revocation'] != _revocationNone)
      {
        continue;
      }

      final endDate = DateTime.tryParse(membership['end_date'] as String);

      if (endDate != null &&
          _isWithinRenewalWindow(endDate, membership['renewal_period_days'] as int))
      {
        return true;
      }
    }

    return false;
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

    if (_isActiveCollaborator && !_hasRunningMembership(payload))
    {
      CustomSnackBar.show(
        context: context,
        message: 'Impossibile impostare "Collaboratore attivo" senza '
            "un'iscrizione in corso.",
        isError: true,
      );

      return;
    }

    setState(() => _isSaving = true);

    try
    {
      await _apiService.updatePersonMemberships(
        widget.person.fiscalCode,
        _isActiveCollaborator,
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

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildForm()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Collaboratore attivo'),
        Center(
          child: WizardYesNoSwitch(
            value: _isActiveCollaborator,
            onChanged: (value) => setState(() => _isActiveCollaborator = value),
          ),
        ),
        const SizedBox(height: 32),
        _buildFieldLabel('Storico Iscrizioni'),
        for (var i = 0; i < _rows.length; i++)
          _MembershipEditRow(
            yearController: _rows[i].yearController,
            dayMonthController: _rows[i].dayMonthController,
            yearError: _errors['year_$i'],
            startError: _errors['start_$i'],
            onYearChanged: (_) => setState(() => _errors.remove('year_$i')),
            onDayMonthChanged: (_) => setState(() => _errors.remove('start_$i')),
            onRemove: () => _removeRow(i),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: WizardTextLinkButton(
            text: 'Aggiungi iscrizione',
            icon: Icons.add_rounded,
            onTap: _addEmptyRow,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Modifica Iscrizioni',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  FadeHoverIconButton(
                    icon: Icons.close,
                    color: AppTheme.primary,
                    hoverColor: AppTheme.iconHover,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: AppTheme.divider),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
                child: SizedBox(width: double.infinity, child: _buildForm()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
              child: ResponsiveDialogButtonsRow(
                stackedButtonWidth: null,
                secondaryButton: AnimatedActionButton(
                  text: 'ANNULLA',
                  icon: Icons.cancel_outlined,
                  baseColor: AppTheme.danger,
                  hoverColor: AppTheme.dangerHover,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                primaryButton: AnimatedActionButton(
                  text: _isSaving ? 'SALVATAGGIO...' : 'SALVA MODIFICHE',
                  icon: Icons.check_circle_outline,
                  baseColor: AppTheme.primary,
                  hoverColor: AppTheme.primaryHover,
                  onPressed: _isSaving ? () {} : _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Year and start date side by side, stacked when the row gets too narrow. Once
// stacked the remove button moves next to the last field, aligned to its bottom.
class _MembershipEditRow extends StatelessWidget
{
  static const double _breakpoint = 360;

  final TextEditingController yearController;
  final TextEditingController dayMonthController;
  final String? yearError;
  final String? startError;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<String> onDayMonthChanged;
  final VoidCallback onRemove;

  const _MembershipEditRow({
    required this.yearController,
    required this.dayMonthController,
    required this.yearError,
    required this.startError,
    required this.onYearChanged,
    required this.onDayMonthChanged,
    required this.onRemove,
  });

  Widget _buildFieldBlock(String label, Widget field)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate500,
          ),
        ),
        const SizedBox(height: 4),
        field,
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final yearField = _buildFieldBlock(
      'Anno',
      WizardAnimatedTextField(
        controller: yearController,
        hint: 'Es. 2024',
        errorText: yearError,
        keyboardType: TextInputType.number,
        onChanged: onYearChanged,
      ),
    );

    final dayMonthField = _buildFieldBlock(
      'Data inizio',
      WizardAnimatedTextField(
        controller: dayMonthController,
        hint: 'gg/mm',
        errorText: startError,
        inputFormatters: [WizardDayMonthInputFormatter()],
        keyboardType: TextInputType.number,
        onChanged: onDayMonthChanged,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.slate200),
        color: _subtleBackground,
      ),
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          if (constraints.maxWidth < _breakpoint)
          {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                yearField,
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: dayMonthField),
                    const SizedBox(width: 8),
                    WizardRemoveRowButton(onTap: onRemove),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: yearField),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: dayMonthField),
              Padding(
                padding: const EdgeInsets.only(top: 22, left: 8),
                child: WizardRemoveRowButton(onTap: onRemove),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Dropdown for a form field: it keeps the backend code as its value and shows the
// matching label. Separate from the filter menus in shared/widgets, which are
// built around clearing and multi selection rather than picking one value.
class _FormOverlayDropdown extends StatefulWidget
{
  final String value;
  final Map<String, String> labels;
  final ValueChanged<String> onSelected;

  const _FormOverlayDropdown({
    required this.value,
    required this.labels,
    required this.onSelected,
  });

  @override
  State<_FormOverlayDropdown> createState() => _FormOverlayDropdownState();
}

class _FormOverlayDropdownState extends State<_FormOverlayDropdown>
{
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey<_FormOverlayContentState> _menuKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  bool _isHovered = false;

  void _toggleMenu()
  {
    if (_overlayEntry != null)
    {
      _closeMenu();
      return;
    }

    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              child: Container(),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 4,
            left: offset.dx,
            child: _FormOverlayContent(
              key: _menuKey,
              currentValue: widget.value,
              labels: widget.labels,
              width: size.width,
              onSelected: (value)
              {
                widget.onSelected(value);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  // The overlay is removed only after the collapse animation has run, so the menu
  // does not disappear abruptly.
  void _closeMenu() async
  {
    if (_overlayEntry == null)
    {
      return;
    }

    await _menuKey.currentState?.hide();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 200),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? AppTheme.primary : AppTheme.slate200,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.labels[widget.value] ?? widget.value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _strongTextColor,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _isHovered ? AppTheme.primary : AppTheme.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormOverlayContent extends StatefulWidget
{
  final String currentValue;
  final Map<String, String> labels;
  final ValueChanged<String> onSelected;
  final double width;

  const _FormOverlayContent({
    super.key,
    required this.currentValue,
    required this.labels,
    required this.onSelected,
    required this.width,
  });

  @override
  State<_FormOverlayContent> createState() => _FormOverlayContentState();
}

class _FormOverlayContentState extends State<_FormOverlayContent>
{
  // The same value drives the AnimatedSize and the delay awaited by hide(): they
  // must stay in sync or the overlay is torn down mid animation.
  static const Duration _expandDuration = Duration(milliseconds: 180);

  bool _expanded = false;

  @override
  void initState()
  {
    super.initState();

    // Expanding on the next frame is what makes the opening animation visible.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(() => _expanded = true);
      }
    });
  }

  Future<void> hide() async
  {
    if (mounted)
    {
      setState(() => _expanded = false);
    }

    await Future.delayed(_expandDuration);
  }

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.overlayShadow,
        ),
        child: AnimatedSize(
          duration: _expandDuration,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.labels.entries.map((entry)
                    {
                      return _FormOverlayMenuItem(
                        text: entry.value,
                        isSelected: widget.currentValue == entry.key,
                        onTap: () => widget.onSelected(entry.key),
                      );
                    }).toList(),
                  ),
                )
              : SizedBox(width: widget.width, height: 0),
        ),
      ),
    );
  }
}

class _FormOverlayMenuItem extends StatefulWidget
{
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormOverlayMenuItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FormOverlayMenuItem> createState() => _FormOverlayMenuItemState();
}

class _FormOverlayMenuItemState extends State<_FormOverlayMenuItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final isHighlighted = _hover || widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: isHighlighted ? 16 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OverflowTooltipText(
                  text: widget.text,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}