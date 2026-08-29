import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'app_dialog_footer.dart';
import 'app_dialog_stack.dart';
import 'app_gradient_button.dart';
import 'app_text_field.dart';
import 'overflow_tooltip_text.dart';

// Used as both ListView itemExtent and tile height: the two must match exactly
// or the scroll math lands on the wrong row.
const double _oneLineItemHeight = 44.0;
const double _twoLineItemHeight = 58.0;

const double _avatarItemHeight = 76.0;

const double _oneLineListHeight = 200;
const double _twoLineListHeight = 290;

const double _optionsListPadding = 8;

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

TextStyle _subtitleTextStyle()
{
  return GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppTheme.trialMutedText,
  );
}

class MultiSelectFilterOption<T extends Object>
{
  final T value;
  final String label;

  final String? subtitle;

  const MultiSelectFilterOption({required this.value, required this.label, this.subtitle});
}

class MultiSelectFilterDialog<T extends Object> extends StatefulWidget
{
  final String title;
  final String hint;
  final List<MultiSelectFilterOption<T>> options;
  final Set<T> initialSelected;
  final ValueChanged<Set<T>> onApply;

  final AutocompleteSubtitlePlacement subtitlePlacement;

  const MultiSelectFilterDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.options,
    required this.initialSelected,
    required this.onApply,
    this.subtitlePlacement = AutocompleteSubtitlePlacement.trailing,
  });

  @override
  State<MultiSelectFilterDialog<T>> createState() => _MultiSelectFilterDialogState<T>();
}

class _MultiSelectFilterDialogState<T extends Object> extends State<MultiSelectFilterDialog<T>>
{
  final TextEditingController _searchController = TextEditingController();

  late Set<T> _selected;

  @override
  void initState()
  {
    super.initState();
    _selected = Set<T>.from(widget.initialSelected);
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  List<MultiSelectFilterOption<T>> get _selectedOptions
  {
    final selected = widget.options.where((option) => _selected.contains(option.value)).toList();
    selected.sort((a, b) => a.label.compareTo(b.label));

    return selected;
  }

  List<MultiSelectFilterOption<T>> get _availableOptions =>
      widget.options.where((option) => !_selected.contains(option.value)).toList();

  void _addOption(MultiSelectFilterOption<T> option)
  {
    setState(() => _selected.add(option.value));
  }

  void _removeOption(T value)
  {
    setState(() => _selected.remove(value));
  }

  void _reset()
  {
    setState(()
    {
      _selected.clear();
      _searchController.clear();
    });
  }

  void _apply()
  {
    widget.onApply(_selected);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context)
  {
    final selectedOptions = _selectedOptions;

    return AppDialogStack(
      eyebrow: 'Filtro',
      title: widget.title,
      maxWidth: 520,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: 'AZZERA',
          icon: Icons.refresh_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _reset,
        ),
        primary: AppGradientButton(
          label: 'APPLICA',
          icon: Icons.check_rounded,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _apply,
        ),
      ),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterAutocompleteField<T>(
                controller: _searchController,
                hint: widget.hint,
                options: _availableOptions,
                subtitlePlacement: widget.subtitlePlacement,
                onSelected: _addOption,
              ),
              const SizedBox(height: 18),
              if (selectedOptions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nessuna selezione.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.trialMutedText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedOptions.map((option)
                  {
                    return AppDeletableChip(
                      label: option.label,
                      subtitle: option.subtitle,
                      onDelete: () => _removeOption(option.value),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterAutocompleteField<T extends Object> extends StatefulWidget
{
  final TextEditingController controller;
  final String hint;
  final List<MultiSelectFilterOption<T>> options;
  final AutocompleteSubtitlePlacement subtitlePlacement;
  final ValueChanged<MultiSelectFilterOption<T>> onSelected;

  const _FilterAutocompleteField({
    required this.controller,
    required this.hint,
    required this.options,
    required this.subtitlePlacement,
    required this.onSelected,
  });

  @override
  State<_FilterAutocompleteField<T>> createState() => _FilterAutocompleteFieldState<T>();
}

class _FilterAutocompleteFieldState<T extends Object> extends State<_FilterAutocompleteField<T>>
{
  static const double width = 436;

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose()
  {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return RawAutocomplete<MultiSelectFilterOption<T>>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.label,
      optionsBuilder: (textEditingValue)
      {
        if (textEditingValue.text.isEmpty)
        {
          return const Iterable.empty();
        }

        final query = textEditingValue.text.toLowerCase();

        return widget.options.where((option) => option.label.toLowerCase().contains(query));
      },
      onSelected: (option)
      {
        widget.onSelected(option);

        // clear() alone leaves the selection collapsed at -1, which renders no caret.
        Future.microtask(()
        {
          widget.controller.clear();
          widget.controller.selection = const TextSelection.collapsed(offset: 0);
          _focusNode.requestFocus();
        });
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted)
      {
        return AppTextField(
          controller: textEditingController,
          focusNode: focusNode,
          label: widget.hint,
          showLabel: false,
          hintText: widget.hint,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => onFieldSubmitted(),
          suffix: textEditingController.text.isEmpty
              ? null
              : MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: ()
                    {
                      textEditingController.clear();
                      setState(() {});
                    },
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(4, 4, 16, 4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 24,
                        color: AppTheme.trialTealDeep,
                      ),
                    ),
                  ),
                ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) =>
          AutocompleteOptionsList<MultiSelectFilterOption<T>>(
        options: options,
        label: (option) => option.label,
        subtitle: (option) => option.subtitle,
        subtitlePlacement: widget.subtitlePlacement,
        width: width,
        onSelected: onSelected,
      ),
    );
  }
}

enum AutocompleteSubtitlePlacement
{
  trailing,
  below,
  above,
}

class AutocompleteOptionsList<T extends Object> extends StatefulWidget
{
  final Iterable<T> options;
  final String Function(T option) label;
  final String? Function(T option)? subtitle;

  final Widget? Function(T option)? leading;

  final AutocompleteSubtitlePlacement subtitlePlacement;
  final AutocompleteOnSelected<T> onSelected;

  final double width;

  const AutocompleteOptionsList({
    super.key,
    required this.options,
    required this.label,
    required this.onSelected,
    required this.width,
    this.subtitle,
    this.leading,
    this.subtitlePlacement = AutocompleteSubtitlePlacement.trailing,
  });

  @override
  State<AutocompleteOptionsList<T>> createState() => _AutocompleteOptionsListState<T>();
}

class _AutocompleteOptionsListState<T extends Object> extends State<AutocompleteOptionsList<T>>
{
  final ScrollController _scrollController = ScrollController();

  int? _lastHighlightedIndex;

  bool get _isTwoLine => widget.subtitlePlacement != AutocompleteSubtitlePlacement.trailing;

  bool get _hasLeading => widget.leading != null;

  double get _itemHeight
  {
    if (_hasLeading)
    {
      return _avatarItemHeight;
    }

    return _isTwoLine ? _twoLineItemHeight : _oneLineItemHeight;
  }

  double get _listHeight => _isTwoLine ? _twoLineListHeight : _oneLineListHeight;

  @override
  void dispose()
  {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureHighlightedVisible(int index)
  {
    if (!_scrollController.hasClients)
    {
      return;
    }

    final itemTop = _optionsListPadding + (index * _itemHeight);
    final itemBottom = itemTop + _itemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final visibleTop = _scrollController.offset;
    final visibleBottom = visibleTop + viewportHeight;

    double? target;

    if (itemTop < visibleTop)
    {
      target = itemTop;
    }
    else if (itemBottom > visibleBottom)
    {
      target = itemBottom - viewportHeight;
    }

    if (target == null)
    {
      return;
    }

    _scrollController.jumpTo(target.clamp(0.0, _scrollController.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context)
  {
    // Reading it here creates the reactive dependency on the notifier.
    final highlightedIndex = AutocompleteHighlightedOption.of(context);

    if (_lastHighlightedIndex != highlightedIndex)
    {
      _lastHighlightedIndex = highlightedIndex;

      // Deferred: the scrollable must be laid out to expose viewportDimension.
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          _ensureHighlightedVisible(highlightedIndex);
        }
      });
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: widget.width,
          margin: const EdgeInsets.only(top: 8),
          constraints: BoxConstraints(maxHeight: _listHeight),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.overlayShadow,
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(10),
              thumbColor: AppTheme.trialLine,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: _optionsListPadding),
                shrinkWrap: true,
                itemExtent: _itemHeight,
                itemCount: widget.options.length,
                itemBuilder: (context, index)
                {
                  final option = widget.options.elementAt(index);

                  return _AutocompleteItem(
                    label: widget.label(option),
                    subtitle: widget.subtitle?.call(option),
                    leading: widget.leading?.call(option),
                    placement: widget.subtitlePlacement,
                    height: _itemHeight,
                    isHighlighted: index == highlightedIndex,
                    onTap: () => widget.onSelected(option),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutocompleteItem extends StatefulWidget
{
  final String label;

  final String? subtitle;

  final AutocompleteSubtitlePlacement placement;
  final double height;

  final Widget? leading;

  final bool isHighlighted;
  final VoidCallback onTap;

  const _AutocompleteItem({
    required this.label,
    required this.subtitle,
    this.leading,
    required this.placement,
    required this.height,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_AutocompleteItem> createState() => _AutocompleteItemState();
}

class _AutocompleteItemState extends State<_AutocompleteItem>
{
  bool _hover = false;

  Widget _buildStackedSubtitle(String subtitle, {required bool above})
  {
    return Padding(
      padding: above ? const EdgeInsets.only(bottom: 2) : const EdgeInsets.only(top: 2),
      child: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _subtitleTextStyle(),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final isActive = widget.isHighlighted || _hover;
    final subtitle = widget.subtitle;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          height: widget.height,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: isActive ? 16 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.trialGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null && widget.placement == AutocompleteSubtitlePlacement.above)
                      _buildStackedSubtitle(subtitle, above: true),
                    OverflowTooltipText(
                      text: widget.label,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
                      ),
                    ),
                    if (subtitle != null && widget.placement == AutocompleteSubtitlePlacement.below)
                      _buildStackedSubtitle(subtitle, above: false),
                  ],
                ),
              ),
              if (subtitle != null && widget.placement == AutocompleteSubtitlePlacement.trailing) ...[
                const SizedBox(width: 8),
                Text(subtitle, style: _subtitleTextStyle()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppDeletableChip extends StatefulWidget
{
  final String label;

  final String? subtitle;

  final VoidCallback onDelete;

  const AppDeletableChip({
    super.key,
    required this.label,
    this.subtitle,
    required this.onDelete,
  });

  @override
  State<AppDeletableChip> createState() => _AppDeletableChipState();
}

class _AppDeletableChipState extends State<AppDeletableChip>
{
  bool _isHovered = false;

  Widget _buildLabel()
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialTealDeep,
    );

    final Widget name = OverflowTooltipText(text: widget.label, maxLines: 1, style: style);

    final String? subtitle = widget.subtitle;

    if (subtitle == null)
    {
      return name;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _subtitleTextStyle(),
          ),
        ),
        name,
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: _isHovered ? AppTheme.trialGold : AppTheme.trialLine,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: _buildLabel()),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.trialGoldSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
