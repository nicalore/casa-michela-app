import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'app_dialog_footer.dart';
import 'app_dialog_stack.dart';
import 'app_gradient_button.dart';
import 'app_text_field.dart';
import 'overflow_tooltip_text.dart';

// Shared between the ListView itemExtent and the height of a single tile: the
// two must match exactly or the scroll math below lands on the wrong row. A row
// carrying a second line needs the room for it.
const double _oneLineItemHeight = 44.0;
const double _twoLineItemHeight = 58.0;

// How much taller a row carrying a face is: the circle is taller than the two
// lines of text, and without this it would be clipped.
const double _avatarItemHeight = 76.0;

// About four rows and a half either way, which is enough to be a list and few
// enough that what is under it is still visible.
const double _oneLineListHeight = 200;
const double _twoLineListHeight = 290;

const double _optionsListPadding = 8;

// The height and type size every dialog of the app gives its buttons.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

/// One answer a filter can be given, and what to write on it.
///
/// Keyed on a value rather than on the label, because the two are not always
/// the same thing: ministry subject names repeat across levels and are told
/// apart by their id, while a discipline taught by a teacher is the word
/// itself.
class MultiSelectFilterOption<T extends Object>
{
  final T value;
  final String label;

  /// Said in small at the end of the row, where two options can be called the
  /// same: the level of a ministry subject. Most have none.
  final String? subtitle;

  const MultiSelectFilterOption({required this.value, required this.label, this.subtitle});
}

/// A filter whose answers are too many for a menu: they are searched for and
/// gathered, several at a time, and what comes back is a count the pill can
/// wear.
///
/// The list in front of you keeps whatever matches at least one of them, which
/// is what makes it worth choosing more than one — three disciplines is "any of
/// these three", not "all three at once".
class MultiSelectFilterDialog<T extends Object> extends StatefulWidget
{
  final String title;
  final String hint;
  final List<MultiSelectFilterOption<T>> options;
  final Set<T> initialSelected;
  final ValueChanged<Set<T>> onApply;

  const MultiSelectFilterDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.options,
    required this.initialSelected,
    required this.onApply,
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

  // Already selected options are not proposed again by the autocomplete.
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
        // Emptying a filter throws nothing away, so it speaks in violet like
        // every other way out of a dialog rather than in red.
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
  final ValueChanged<MultiSelectFilterOption<T>> onSelected;

  const _FilterAutocompleteField({
    required this.controller,
    required this.hint,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_FilterAutocompleteField<T>> createState() => _FilterAutocompleteFieldState<T>();
}

class _FilterAutocompleteFieldState<T extends Object> extends State<_FilterAutocompleteField<T>>
{
  // How wide the field is inside the card of the filter dialog.
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

        // clear() alone leaves the selection collapsed at -1, which Flutter
        // renders as no caret at all, so it is restored explicitly.
        Future.microtask(()
        {
          widget.controller.clear();
          widget.controller.selection = const TextSelection.collapsed(offset: 0);
          _focusNode.requestFocus();
        });
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted)
      {
        // The app's own field and not one rebuilt here: a hand-drawn box with
        // a fixed border answered neither the pointer nor focus, which made the
        // one place on the page that is listening the only one not saying so.
        // AppTextField takes a focus node from outside for exactly this.
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
                    onTap: ()
                    {
                      textEditingController.clear();
                      setState(() {});
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.trialGoldSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
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
        width: width,
        onSelected: onSelected,
      ),
    );
  }
}

/// Where the second thing a row says belongs.
///
/// A qualifier of a word or two — a province, the level of a subject — goes at
/// the end of the row, small, where it reads as part of the answer. A line of
/// its own — the subjects a teacher teaches — goes under the label, because at
/// the end of the row it would be squeezed into nothing.
enum AutocompleteSubtitlePlacement
{
  trailing,
  below,
}

/// The list that opens under a field with completion. On subjects it carries
/// options with an id, on cities a city and its province, on teachers a name
/// and what they teach: what is written on a row is said by the two functions,
/// and the rest — the shape, the scrolling, the mark under the arrow — is the
/// same and is written once.
class AutocompleteOptionsList<T extends Object> extends StatefulWidget
{
  final Iterable<T> options;
  final String Function(T option) label;
  final String? Function(T option)? subtitle;

  // Something before the name, where the entry is a person: a face is
  // recognised before a surname, and is often the only handle a searcher has.
  final Widget? Function(T option)? leading;

  final AutocompleteSubtitlePlacement subtitlePlacement;
  final AutocompleteOnSelected<T> onSelected;

  // The list stands above everything, in an overlay: the width of the field it
  // opens under does not reach it through the constraints, so whoever opens it
  // has to say.
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

  bool get _isTwoLine => widget.subtitlePlacement == AutocompleteSubtitlePlacement.below;

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

  // Scrolls by the minimum needed to reveal the arrow-highlighted option,
  // rather than always centring it.
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
    // Reading it here is what creates the reactive dependency on the notifier,
    // so this widget rebuilds on every arrow key press.
    final highlightedIndex = AutocompleteHighlightedOption.of(context);

    if (_lastHighlightedIndex != highlightedIndex)
    {
      _lastHighlightedIndex = highlightedIndex;

      // Deferred: the scrollable must already be laid out to expose
      // viewportDimension and maxScrollExtent.
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
          // Keeps the highlighted row from painting over the rounded corners.
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

  // The second thing the row says, where it has one: the level of a subject,
  // the province of a city, the subjects of a teacher. A sector has none.
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
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.trialMutedText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (subtitle != null && widget.placement == AutocompleteSubtitlePlacement.trailing) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One answer already given to a filter, with the cross that takes it back.
class AppDeletableChip extends StatefulWidget
{
  final String label;
  final VoidCallback onDelete;

  const AppDeletableChip({super.key, required this.label, required this.onDelete});

  @override
  State<AppDeletableChip> createState() => _AppDeletableChipState();
}

class _AppDeletableChipState extends State<AppDeletableChip>
{
  bool _isHovered = false;

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
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialTealDeep,
              ),
            ),
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
