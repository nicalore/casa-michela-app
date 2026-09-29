import 'package:flutter/material.dart';

import '../../../shared/widgets/page_transition.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_widgets.dart';

const double _cardsWidth = 1600;

class PersonAccountTab extends StatelessWidget
{
  final PersonItem person;

  const PersonAccountTab({super.key, required this.person});

  @override
  Widget build(BuildContext context)
  {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: pageTransitionBlocks([
              const PersonSectionTitle('Account'),
              const SizedBox(height: kPersonTitleGap),
            ]),
          ),
        ),
      ),
    );
  }
}
