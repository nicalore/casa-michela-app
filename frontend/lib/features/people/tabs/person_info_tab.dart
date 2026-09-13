import 'package:flutter/material.dart';

import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_cards.dart';
import '../widgets/person_detail_widgets.dart';

class PersonInfoTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onEdit;

  // Null when the person has no enrollment form to generate.
  final VoidCallback? onGenerateForm;

  final bool isGeneratingForm;

  const PersonInfoTab({
    super.key,
    required this.person,
    required this.onEdit,
    this.onGenerateForm,
    this.isGeneratingForm = false,
  });

  Widget _buildFullWidthCard(PersonDetailCard card)
  {
    return SizedBox(width: double.infinity, child: card);
  }

  @override
  Widget build(BuildContext context)
  {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: pageTransitionBlocks([
              PersonDetailCardPair(
                first: identityCard(person),
                second: residenceCard(person),
              ),
              const SizedBox(height: 24),
              PersonDetailCardPair(
                first: birthCard(person),
                second: contactsCard(person),
              ),
              for (final card in roleDetailCards(person)) ...[
                const SizedBox(height: 24),
                _buildFullWidthCard(card),
              ],
              const SizedBox(height: 48),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    AppGradientButton(
                      label: 'MODIFICA ANAGRAFICA',
                      icon: Icons.edit_rounded,
                      onPressed: onEdit,
                    ),
                    if (onGenerateForm case final VoidCallback generate)
                      AppGradientButton(
                        label: 'GENERA DOCUMENTI DI ISCRIZIONE',
                        icon: Icons.picture_as_pdf_outlined,
                        busy: isGeneratingForm,
                        onPressed: generate,
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
