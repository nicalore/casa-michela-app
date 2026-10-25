import 'package:flutter/material.dart';

import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../models/person_item.dart';
import '../models/student_note_item.dart';
import '../own_tour.dart';
import '../utils/student_notes_strings.dart';
import '../widgets/criteria_dialog.dart';
import '../widgets/student_notes_card.dart';

const double _cardsWidth = 1200;
const double _shadowRoom = 16;

// A teacher's own: what the administrators wrote about them, read-only.
class OwnObservationsTab extends StatelessWidget
{
  final PersonItem person;

  const OwnObservationsTab({super.key, required this.person});

  Future<void> _showCriteria(BuildContext context) async
  {
    ownCriteriaShown.value = true;
    await showCriteriaDialog(context);
    ownCriteriaShown.value = false;
  }

  Widget _buildButton(BuildContext context)
  {
    return DesktopTourTarget(
      id: kTourOwnCriteria,
      child: CriteriaButton(onTap: () => _showCriteria(context)),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<StudentNoteItem> notes = person.administratorNotes ?? const [];

    // No card to hold the (i): it floats where the card's head would be.
    if (notes.isEmpty)
    {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Stack(
            children: [
              const AppEmptyRoom(
                card: AppEmptyCard(icon: Icons.speaker_notes_off_rounded, message: kNoObservations),
                tourId: kTourOwnObservations,
              ),
              Positioned(
                top: _shadowRoom,
                right: 0,
                child: pageTransitionBlocks([_buildButton(context)]).single,
              ),
            ],
          ),
        ),
      );
    }

    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: _shadowRoom, bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _cardsWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pageTransitionBlocks([
                DesktopTourTarget(
                  id: kTourOwnObservations,
                  child: StudentNotesCard(
                    title: kObservationsTitle,
                    icon: Icons.edit_note_rounded,
                    taxCode: person.fiscalCode,
                    kind: StudentNoteKind.administrator,
                    notes: notes,
                    trailing: _buildButton(context),
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
