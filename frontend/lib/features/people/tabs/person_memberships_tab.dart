import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/card_scroll_area.dart';
import '../models/membership_item.dart';
import '../models/person_item.dart';
import '../widgets/membership_edit_row.dart';
import '../widgets/person_detail_widgets.dart';

const double _statusCardWidth = 500;

const double _cardsWidth = 1600;

const Color _collaboratingSurface = Color(0xFFE8F7F5);
const Color _revokedSurface = Color(0xFFFBEDEA);

const Map<String, String> _revocationLabels = {
  MembershipItem.revocationExpulsion: 'Espulsione',
  MembershipItem.revocationResignation: 'Dimissioni',
};

// The dialog has no field for the renewal period, so new rows get the standard.
const int _defaultRenewalPeriodDays = 30;

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
final DateFormat _dayMonthFormat = DateFormat('dd/MM');

// A membership counts as running until the renewal window has passed, not on
// the end date itself.
bool _isWithinRenewalWindow(DateTime endDate, int renewalPeriodDays)
{
  return DateTime.now().isBefore(endDate.add(Duration(days: renewalPeriodDays)));
}

class PersonMembershipsTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  // Revoking your own membership is not allowed, so the button is hidden.
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _statusCardWidth),
        child: SelectionArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
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
                      color: isEnrolled ? AppTheme.trialSeaGreen : AppTheme.trialDanger,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        statusText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.trialOcean,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActiveCollaborator ? _collaboratingSurface : AppTheme.trialPaper,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActiveCollaborator
                            ? Icons.handshake_rounded
                            : Icons.work_off_rounded,
                        color: isActiveCollaborator
                            ? AppTheme.trialTealDeep
                            : AppTheme.trialMutedText,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          collaborationText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isActiveCollaborator
                                ? AppTheme.trialTealDeep
                                : AppTheme.trialMutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipCard(MembershipItem membership, {required bool isCurrent})
  {
    final isRevoked = membership.isRevoked;
    final deadline = membership.endDate.add(Duration(days: membership.renewalPeriodDays));

    return AppCard(
      title: 'Anno ${membership.year}',
      compact: true,
      leading: AppCardBadge(
        icon: isCurrent ? Icons.workspace_premium_rounded : Icons.history_rounded,
        compact: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRevoked) ...[
            Center(
              child: _RevokedNotice(
                label: _revocationLabels[membership.revocation] ?? membership.revocation,
              ),
            ),
            const SizedBox(height: 20),
          ],
          PersonFactsRow(
            facts: [
              PersonFact('Data inizio', _dateFormat.format(membership.startDate)),
              PersonFact('Data fine', _dateFormat.format(membership.endDate)),
              if (isCurrent)
                PersonFact(
                  'Rinnovo entro',
                  isRevoked ? missingValue : _dateFormat.format(deadline),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context)
  {
    final Widget edit = AppGradientButton(
      label: 'MODIFICA ISCRIZIONI',
      icon: Icons.edit_rounded,
      onPressed: () => _showEditDialog(context),
    );

    if (isOwnProfile)
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

  @override
  Widget build(BuildContext context)
  {
    final memberships = [...?person.memberships];
    memberships.sort((a, b) => b.year.compareTo(a.year));

    final latest = memberships.isNotEmpty ? memberships.first : null;

    final isRevoked = latest != null && latest.isRevoked;
    final isEnrolled = latest != null &&
        !latest.isRevoked &&
        _isWithinRenewalWindow(latest.endDate, latest.renewalPeriodDays);

    // Only the most recent membership can be the running one.
    final currentMembership = isEnrolled ? latest : null;
    final pastMemberships = isEnrolled ? memberships.skip(1).toList() : memberships;

    final isFemale = person.gender == 'F';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: pageTransitionBlocks([
              _buildStatusCard(
                isEnrolled: isEnrolled,
                isFemale: isFemale,
                // Collaboration only counts while the membership is running.
                isActiveCollaborator: isEnrolled && (person.isActiveCollaborator ?? false),
              ),
              const SizedBox(height: kPersonSectionGap),
              if (currentMembership != null) ...[
                const PersonSectionTitle('Iscrizione attuale'),
                const SizedBox(height: kPersonTitleGap),
                _buildMembershipCard(currentMembership, isCurrent: true),
                const SizedBox(height: kPersonSectionGap),
              ],
              if (pastMemberships.isNotEmpty) ...[
                const PersonSectionTitle('Iscrizioni passate'),
                const SizedBox(height: kPersonTitleGap),
                for (var i = 0; i < pastMemberships.length; i++) ...[
                  if (i > 0) const SizedBox(height: kPersonCardGap),
                  _buildMembershipCard(pastMemberships[i], isCurrent: false),
                ],
              ],
              if (currentMembership == null && pastMemberships.isEmpty)
                const PersonEmptyState(message: 'Nessuna iscrizione registrata.'),
              if (!isRevoked && latest != null) ...[
                const SizedBox(height: kPersonSectionGap),
                Center(child: _buildActions(context)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _RevokedNotice extends StatelessWidget
{
  final String label;

  const _RevokedNotice({required this.label});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _revokedSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gavel_rounded, size: 18, color: AppTheme.trialDanger),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Iscrizione revocata ($label)',
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
              'e lo stato di collaborazione verrà disattivato.',
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
      final int year = earliestYear == null ? DateTime.now().year : earliestYear - 1;

      _rows.add(_MembershipRowData(
        yearController: TextEditingController(text: year.toString()),
        dayMonthController: TextEditingController(),
        revocation: MembershipItem.revocationNone,
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

    // DateTime rolls over invalid values (31/02 becomes 02/03), so compare the
    // components back.
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

  bool _hasRunningMembership(List<Map<String, dynamic>> payload)
  {
    for (final membership in payload)
    {
      if (membership['revocation'] != MembershipItem.revocationNone)
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppFieldLabel('Collaboratore attivo'),
              const SizedBox(height: 12),
              AppSegmentedSwitch(
                value: _isActiveCollaborator,
                trueLabel: 'Sì',
                falseLabel: 'No',
                hugContent: true,
                onChanged: (value) => setState(() => _isActiveCollaborator = value),
              ),
            ],
          ),
        ),
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
