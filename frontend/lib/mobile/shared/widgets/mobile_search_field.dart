import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

const String kMobileNoSearchMatch = 'Nessun elemento trovato per questa ricerca.';

const double _height = 46;
const double _radius = 18;

const double _fillAlpha = 0.45;
const double _edgeAlpha = 0.6;

class MobileSearchField extends StatelessWidget
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

  void _clear()
  {
    controller.clear();
    onChanged('');
  }

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: onGlass ? 0.75 : _fillAlpha),
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
              onChanged: onChanged,
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
                hintText: hintText,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.trialInk.withValues(alpha: 0.45),
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
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.trialInk.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
