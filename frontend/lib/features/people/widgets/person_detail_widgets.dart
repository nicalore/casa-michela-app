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

const double _rowGap = 16;

const double kPersonTitleGap = 20;
const double kPersonCardGap = 24;

// Keeps the last row's shadow from being clipped by the scroll view.
const double kPersonGridShadowRoom = 12;
const double kPersonSectionGap = 56;

// Centres a round icon button on the box of an AppTextField beside it.
const double kPersonFieldButtonSize = 36;
const double kPersonFieldButtonInset =
    AppTextField.labelBlockHeight + (AppTextField.boxHeight - kPersonFieldButtonSize) / 2;

const double kPersonDialogButtonHeight = 52;
const double kPersonDialogButtonFontSize = 14;

// Shared by all wide cards so their value columns align; fits the longest label.
const double kPersonWideCardLabelWidth = 230;

const String missingValue = '-';

String orDash(String? value)
{
  final trimmed = value?.trim();

  return trimmed == null || trimmed.isEmpty ? missingValue : trimmed;
}

class DetailRowData
{
  final String label;
  final String value;

  final bool isSensitive;

  final Widget? valueWidget;

  const DetailRowData(this.label, this.value, {this.isSensitive = false})
      : valueWidget = null;

  const DetailRowData.drawn(this.label, this.valueWidget)
      : value = '',
        isSensitive = false;
}

// The LayoutBuilder must stay outside IntrinsicHeight: intrinsic measurement
// cannot resolve one and throws.
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

class PersonDetailCard extends StatelessWidget
{
  final String title;
  final IconData icon;

  // A null entry renders as an invisible row, padding the shorter card of a pair.
  final List<DetailRowData?> rows;

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
          valueWidget: rowData.valueWidget,
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

// Visibility is per row, so revealing one value does not expose the others.
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

  bool get _hasValue => widget.value.isNotEmpty && widget.value != missingValue;

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

class PersonFact
{
  final String label;
  final String value;

  final int flex;

  final bool highlight;

  const PersonFact(this.label, this.value, {this.flex = 1, this.highlight = false});

  double get minWidth => 90 + 30.0 * flex;
}

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

        // FlexFit.loose: at full share a short value pushed the row off the card.
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


// Fixed height with the actions band always present, or the grid jumps.
class PersonPickerCard extends StatefulWidget
{
  static const double width = 230;
  static const double height = 216;
  static const double _avatarSize = 76;
  static const double _actionsHeight = 36;

  final PersonItem person;
  final bool isSelected;
  final VoidCallback onTap;

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
    // A card with its own action buttons is not tappable as a whole.
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
