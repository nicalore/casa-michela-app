import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/utils/phone_number.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../edit/person_edit_dialog.dart';
import '../edit/person_edit_form.dart' show kBornAbroadProvince;
import '../models/parent_item.dart';
import '../widgets/person_detail_widgets.dart';

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

// A teacher's parent is on record for paperwork only: no link management, no pickup.
class PersonTeacherParentTab extends StatefulWidget
{
  final ParentItem parent;
  final VoidCallback onUpdate;

  const PersonTeacherParentTab({super.key, required this.parent, required this.onUpdate});

  @override
  State<PersonTeacherParentTab> createState() => _PersonTeacherParentTabState();
}

class _PersonTeacherParentTabState extends State<PersonTeacherParentTab>
{
  bool _isOpening = false;

  // The dialog edits the whole record, which the parent entry does not carry.
  Future<void> _openEditDialog() async
  {
    if (_isOpening)
    {
      return;
    }

    setState(() => _isOpening = true);

    try
    {
      final person = await ApiService().getPerson(widget.parent.fiscalCode);

      if (!mounted)
      {
        return;
      }

      setState(() => _isOpening = false);

      final String? saved = await showBlurredDialog<String>(
        context: context,
        barrierLabel: 'PersonEdit',
        builder: (context) => PersonEditDialog(person: person),
      );

      if (saved != null)
      {
        widget.onUpdate();
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _isOpening = false);
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  String _residenceAddress(ParentItem parent)
  {
    final joined =
        '${parent.residenceType?.trim() ?? ''} ${parent.address?.trim() ?? ''}'.trim();

    return joined.isEmpty ? missingValue : joined;
  }

  List<Widget> _buildDetailCards(ParentItem parent)
  {
    final birthDate =
        parent.birthDate != null ? _dateFormat.format(parent.birthDate!) : missingValue;
    final isBornAbroad = parent.birthProvince == kBornAbroadProvince;

    return [
      PersonDetailCardPair(
        first: PersonDetailCard(
          title: 'Identità',
          icon: Icons.badge_rounded,
          rows: [
            DetailRowData('Nome', parent.firstName),
            DetailRowData('Cognome', parent.lastName),
            DetailRowData('Sesso', orDash(parent.gender)),
            DetailRowData('Codice fiscale', parent.fiscalCode),
            null,
          ],
        ),
        second: PersonDetailCard(
          title: 'Residenza',
          icon: Icons.home_rounded,
          rows: [
            DetailRowData('Indirizzo', _residenceAddress(parent)),
            DetailRowData('N°', orDash(parent.addressNumber)),
            DetailRowData('Città', orDash(parent.city)),
            DetailRowData('Provincia', orDash(parent.province)),
            DetailRowData('CAP', orDash(parent.zipCode)),
          ],
        ),
      ),
      const SizedBox(height: 24),
      PersonDetailCardPair(
        first: PersonDetailCard(
          title: 'Dati anagrafici',
          icon: Icons.cake_rounded,
          rows: [
            DetailRowData('Data di nascita', birthDate),
            DetailRowData('Città di nascita', orDash(parent.birthCity)),
            DetailRowData(
              isBornAbroad ? 'Nazione' : 'Provincia',
              orDash(isBornAbroad ? parent.birthNation : parent.birthProvince),
            ),
          ],
        ),
        second: PersonDetailCard(
          title: 'Contatti',
          icon: Icons.alternate_email_rounded,
          rows: [
            DetailRowData('Email', orDash(parent.email)),
            DetailRowData('Telefono', orDash(formatPhoneNumber(parent.phoneNumber))),
            null,
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: pageTransitionBlocks([
                ..._buildDetailCards(widget.parent),
                const SizedBox(height: 48),
                Center(
                  child: AppGradientButton(
                    label: 'MODIFICA GENITORE',
                    icon: Icons.edit_rounded,
                    busy: _isOpening,
                    onPressed: _openEditDialog,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
