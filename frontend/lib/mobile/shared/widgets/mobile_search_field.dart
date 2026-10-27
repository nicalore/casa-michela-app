import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../mobile_palette.dart';

const double _height = 46;
const double _radius = 18;

// Thinner on the sea, the hint drops below 4.5:1 near the deep water.
const double _fillAlpha = 0.75;
const double _edgeAlpha = 0.6;

class MobileSearchField extends StatefulWidget
{
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool onGlass;

  const MobileSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onGlass = false,
  });

  @override
  State<MobileSearchField> createState() => _MobileSearchFieldState();
}

class _MobileSearchFieldState extends State<MobileSearchField>
{
  final FocusNode _focus = FocusNode();

  // A touch outside that lifts where it began was a tap and takes the cursor away; a drag scrolls and keeps it.
  PointerDownEvent? _outside;

  @override
  void dispose()
  {
    _focus.dispose();
    super.dispose();
  }

  void _clear()
  {
    widget.controller.clear();
    widget.onChanged('');
  }

  void _liftedOutside(PointerUpEvent event)
  {
    final PointerDownEvent? down = _outside;
    final double slop = MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;

    _outside = null;

    if (down != null && down.pointer == event.pointer && (event.position - down.position).distance < slop)
    {
      _focus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final TextEditingController controller = widget.controller;
    final bool onGlass = widget.onGlass;

    // The whole bar counts as the field, so its icon and × keep the cursor.
    return TextFieldTapRegion(
      child: Container(
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _fillAlpha),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: onGlass
                ? AppTheme.trialInk.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: _edgeAlpha),
          ),
          boxShadow: onGlass
              ? null
              : const [BoxShadow(color: Color(0x28000000), offset: Offset(0, 10), blurRadius: 22)],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: AppTheme.trialTealDeep),
            const SizedBox(width: 11),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: _focus,
                onChanged: widget.onChanged,
                onTapOutside: (event) => _outside = event,
                onTapUpOutside: _liftedOutside,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.trialInk,
                ),
                cursorColor: AppTheme.trialTealDeep,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: widget.hintText,
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MobilePalette.mutedText,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _clear,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: MobilePalette.mutedText,
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
