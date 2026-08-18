import 'package:flutter/material.dart';

import '../../../shared/widgets/app_check_mark.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/shared_components.dart';
import '../models/person_item.dart';

// The pieces the tabs of a person's page are built from. The panel is AppCard's
// and the rows are AppInfoRow's — the same objects the settings pages are made
// of, since they are showing the same thing: a person's own values, read only.

const double _rowGap = 16;

// The vertical rhythm of a section, and the whole of what says which card
// belongs with which heading: cards of one run are close, a run and the heading
// of the next are far apart. With one gap for both, a page of cards reads as an
// undifferentiated stack — which is what it was.
const double kPersonTitleGap = 20;
const double kPersonCardGap = 24;

// The room a grid of cards leaves inside its own scroll view. A card casts a
// shadow beyond its edges and a scroll view clips whatever leaves its own:
// without this, the last row reaches the clipping edge and has its shadow cut
// clean off, which looks like a sliced card.
const double kPersonGridShadowRoom = 12;
const double kPersonSectionGap = 56;

// Where a round icon button has to start to sit on the middle of the box of an
// AppTextField beside it, rather than on the middle of the whole field — label
// included — or a dozen pixels above it.
const double kPersonFieldButtonSize = 36;
const double kPersonFieldButtonInset =
    AppTextField.labelBlockHeight + (AppTextField.boxHeight - kPersonFieldButtonSize) / 2;

// The two buttons at the foot of every window opened from this page, at the
// size the rest of the app's dialogs use.
const double kPersonDialogButtonHeight = 52;
const double kPersonDialogButtonFontSize = 14;

// Placeholder shown wherever a value is missing.
const String missingValue = '-';

// Trims and falls back to [missingValue], so a field made of spaces reads as
// absent rather than blank.
String orDash(String? value)
{
  final trimmed = value?.trim();

  return trimmed == null || trimmed.isEmpty ? missingValue : trimmed;
}

// One label and value pair inside a [PersonDetailCard].
class DetailRowData
{
  final String label;
  final String value;

  // Renders the value masked with a reveal toggle. Used for the fields that
  // should not be readable by anyone glancing at the screen.
  final bool isSensitive;

  const DetailRowData(this.label, this.value, {this.isSensitive = false});
}

// Side by side above the breakpoint, stacked below it. The two cards are
// stretched to equal height, so a short one does not look truncated next to a
// tall one.
//
// The LayoutBuilder stays outside IntrinsicHeight and must never end up inside
// it: intrinsic measurement cannot resolve a LayoutBuilder and throws. That
// holds for everything the two cards are made of as well — AppCard and
// AppInfoRow both decide their layout without measuring, which is what lets
// them stand in here.
class PersonDetailCardPair extends StatelessWidget
{
  static const double _breakpoint = 820.0;
  static const double _gap = 24;

  final Widget first;
  final Widget second;

  const PersonDetailCardPair({super.key, required this.first, required this.second});

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _breakpoint)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: _gap),
              second,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first),
              const SizedBox(width: _gap),
              Expanded(child: second),
            ],
          ),
        );
      },
    );
  }
}

// A card of the person's own values: the badge and heading of every card in the
// app, and a column of label and value pairs under the rule.
class PersonDetailCard extends StatelessWidget
{
  final String title;
  final IconData icon;

  // A null entry renders as an invisible row: it pads the shorter card so the
  // visible rows of two cards side by side stay on the same lines.
  final List<DetailRowData?> rows;

  // Width of the label column. Cards with long labels need more room, and the
  // two halves of a pair usually differ.
  final double labelWidth;

  const PersonDetailCard({
    super.key,
    required this.title,
    required this.icon,
    required this.rows,
    this.labelWidth = 160,
  });

  List<Widget> _buildRows()
  {
    final widgets = <Widget>[];

    for (var i = 0; i < rows.length; i++)
    {
      final rowData = rows[i];

      Widget row;

      if (rowData == null)
      {
        row = Opacity(
          opacity: 0,
          child: AppInfoRow(
            label: missingValue,
            value: missingValue,
            labelWidth: labelWidth,
          ),
        );
      }
      else if (rowData.isSensitive)
      {
        row = _ObscurableDetailRow(
          label: rowData.label,
          value: rowData.value,
          labelWidth: labelWidth,
        );
      }
      else
      {
        row = AppInfoRow(
          label: rowData.label,
          value: rowData.value,
          labelWidth: labelWidth,
        );
      }

      if (i != rows.length - 1)
      {
        row = Padding(padding: const EdgeInsets.only(bottom: _rowGap), child: row);
      }

      widgets.add(row);
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: title,
      leading: AppCardBadge(icon: icon),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildRows(),
      ),
    );
  }
}

// Masked by default, revealed by the eye toggle. The visibility lives on the
// single row rather than on the whole card, so revealing one value does not
// expose the others.
class _ObscurableDetailRow extends StatefulWidget
{
  final String label;
  final String value;
  final double labelWidth;

  const _ObscurableDetailRow({
    required this.label,
    required this.value,
    required this.labelWidth,
  });

  @override
  State<_ObscurableDetailRow> createState() => _ObscurableDetailRowState();
}

class _ObscurableDetailRowState extends State<_ObscurableDetailRow>
{
  bool _isVisible = false;

  // No toggle when there is nothing to reveal: hiding a dash makes no sense.
  bool get _hasValue => widget.value.isNotEmpty && widget.value != missingValue;

  // Replaces every non space character with a dot, so the grouping of the
  // original value stays readable while masked.
  String get _maskedValue => widget.value.replaceAll(RegExp(r'[^\s]'), '•');

  @override
  Widget build(BuildContext context)
  {
    final displayValue = !_hasValue
        ? widget.value
        : (_isVisible ? widget.value : _maskedValue);

    return AppInfoRow(
      label: widget.label,
      value: displayValue,
      labelWidth: widget.labelWidth,
      // A row of bullets is one long word without it.
      valueLetterSpacing: (_hasValue && !_isVisible) ? 3 : 0,
      trailing: !_hasValue
          ? null
          : IconButton(
              onPressed: () => setState(() => _isVisible = !_isVisible),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                _isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 22,
                color: AppTheme.trialMutedText,
              ),
            ),
    );
  }
}

// One of the facts across a card: what it is over what it says.
class PersonFact
{
  final String label;
  final String value;

  // Share of the row this one takes. The facts of a card are not the same size
  // of thing: the name of a school or of a study programme runs to a line of
  // text, while a class is a roman numeral and a repeated year is yes or no.
  // Given the row in equal parts, the names wrap to three lines beside columns
  // of white.
  final int flex;

  // Draws the value in the danger colour. For the one fact on these cards that
  // is worth stopping at — a school year repeated.
  final bool highlight;

  const PersonFact(this.label, this.value, {this.flex = 1, this.highlight = false});

  // Under this the column stops being readable, whatever share it was given.
  // Wider facts need more of it, which is the whole reason they are wider.
  double get minWidth => 90 + 30.0 * flex;
}

// The facts of a membership or of a school year, side by side across the card
// rather than one under the other: three or five short values in a column is a
// long card saying very little, while a row of them can be read at a glance.
//
// They stack only when the card is too narrow to hold them, which depends on how
// many there are.
class PersonFactsRow extends StatelessWidget
{
  static const double _stackedGap = 20;

  final List<PersonFact> facts;

  const PersonFactsRow({super.key, required this.facts});

  Widget _buildFact(PersonFact fact)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          fact.label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          fact.value,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: fact.highlight ? AppTheme.trialDanger : AppTheme.trialInk,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double needed = facts.fold(0, (sum, fact) => sum + fact.minWidth);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < needed)
        {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < facts.length; i++) ...[
                if (i > 0) const SizedBox(height: _stackedGap),
                _buildFact(facts[i]),
              ],
            ],
          );
        }

        // Each fact takes what it needs, up to the share it was given, and what
        // none of them needed is shared out evenly between them and at the two
        // ends. Columns held open at their full share instead put a hole where a
        // short value was — "cdcd" alone in four hundred pixels — and pushed the
        // rest of the row off to the right of the card.
        //
        // Loose is what allows both: a fact longer than its share still wraps
        // inside it rather than running off the card.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final fact in facts)
              Flexible(
                flex: fact.flex,
                fit: FlexFit.loose,
                child: _buildFact(fact),
              ),
          ],
        );
      },
    );
  }
}


// Someone being picked in a dialog — a parent, a child. It is the card of the
// people list, cut down: the picture over the name, and no roles, because what
// is being asked here is "which person", not "what do they do".
//
// The height is fixed and the band under the name is always there, empty until
// the card is chosen: without it the grid would jump every time one is picked.
class PersonPickerCard extends StatefulWidget
{
  static const double width = 230;
  static const double height = 216;
  static const double _avatarSize = 76;
  static const double _actionsHeight = 36;

  final PersonItem person;
  final bool isSelected;
  final VoidCallback onTap;

  // Given only where a chosen card has something more to say than "chosen": the
  // authorisation to collect a child is edited from here.
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const PersonPickerCard({
    super.key,
    required this.person,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
    this.onRemove,
  });

  @override
  State<PersonPickerCard> createState() => _PersonPickerCardState();
}

class _PersonPickerCardState extends State<PersonPickerCard>
{
  bool _hover = false;

  Widget _buildAvatar()
  {
    final String initials =
        '${widget.person.firstName[0]}${widget.person.lastName[0]}'.toUpperCase();

    final Widget fallback = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );

    String? imageUrl = widget.person.profileImageUrl?.trim();

    if (imageUrl != null && imageUrl.startsWith('/'))
    {
      imageUrl = ApiConfig.buildUrl(imageUrl);
    }

    return Container(
      width: PersonPickerCard._avatarSize,
      height: PersonPickerCard._avatarSize,
      decoration: BoxDecoration(
        color: AppTheme.trialTurquoise.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.trialTurquoise, width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // A chosen card carrying its own actions is no longer tappable as a whole:
    // with the two buttons on it, a tap anywhere else would be a third meaning
    // for the same card.
    final bool hasActions =
        widget.isSelected && (widget.onEdit != null || widget.onRemove != null);

    return MouseRegion(
      cursor: hasActions ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: hasActions ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: PersonPickerCard.width,
          height: PersonPickerCard.height,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: widget.isSelected ? kPickedSurface : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _hover
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _buildAvatar(),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: OverflowTooltipText(
                    text: '${widget.person.firstName} ${widget.person.lastName}',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.trialOcean,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: PersonPickerCard._actionsHeight,
                child: hasActions
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.onEdit != null)
                            FadeHoverIconButton(
                              icon: Icons.edit_outlined,
                              color: AppTheme.trialTealDeep,
                              hoverColor: AppTheme.trialGoldSurface,
                              onTap: widget.onEdit!,
                            ),
                          if (widget.onRemove != null)
                            FadeHoverIconButton(
                              icon: Icons.delete_outline_rounded,
                              color: AppTheme.trialDanger,
                              hoverColor: AppTheme.trialGoldSurface,
                              onTap: widget.onRemove!,
                            ),
                        ],
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// What adds another row to an editable list. The app's button at a smaller size:
// it answers the pointer with the same flood the two at the foot do, because it
// is the same kind of thing — something that happens when you press it.
// The mark that says whether something is in or out. Filled with the brand ramp
// when it is in, an outline when it is not, and a dash where it stands for a
// group only some of whose rows are in.
//
// onTap is left out where the mark is decoration on a row that is itself
// tappable: two hit targets for one answer is one too many.

// One row of an editable list inside a dialog: the fields on a ground of their
// own, so a list of three of them reads as three things rather than as six
// fields in a column.
class PersonEditRow extends StatelessWidget
{
  final Widget child;

  const PersonEditRow({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

// A small, quiet action inside a dialog — selecting all of something, clearing
// it — where a gradient button would be shouting as loudly as SALVA at the foot.
// Outlined, and gold when the pointer arrives.

// A heading over a run of cards inside a tab — "Iscrizione attuale" over the
// membership that is running. Smaller than a card's own title, because it names
// a group of cards rather than what is in one.
class PersonSectionTitle extends StatelessWidget
{
  final String text;

  const PersonSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialOcean,
      ),
    );
  }
}

// What a tab says when it has nothing to show: the sentence, and where there is
// something to be done about it, the button that does it.
class PersonEmptyState extends StatelessWidget
{
  final String message;
  final Widget? action;

  const PersonEmptyState({super.key, required this.message, this.action});

  @override
  Widget build(BuildContext context)
  {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.trialMutedText,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
