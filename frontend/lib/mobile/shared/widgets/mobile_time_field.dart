import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../mobile_palette.dart';

const double _height = 44;
const double _radius = 14;
const double _buttonSize = 36;

const Duration _repeatAfter = Duration(milliseconds: 400);
const Duration _repeatEvery = Duration(milliseconds: 110);

// Minutes from midnight for "1430", "14:30", "14.30", "930" or "9"; else null.
int? parseTypedTime(String text)
{
  final String trimmed = text.trim();

  if (trimmed.isEmpty)
  {
    return null;
  }

  final List<String> parts = trimmed.split(RegExp(r'[:.]'));
  final String hours;
  final String minutes;

  if (parts.length == 2)
  {
    hours = parts[0];
    minutes = parts[1].padRight(2, '0');
  }
  else if (parts.length == 1)
  {
    final String digits = parts.single;

    hours = digits.length <= 2 ? digits : digits.substring(0, digits.length - 2);
    minutes = digits.length <= 2 ? '00' : digits.substring(digits.length - 2);
  }
  else
  {
    return null;
  }

  final int? hour = int.tryParse(hours);
  final int? minute = int.tryParse(minutes);

  if (hour == null || minute == null || hours.length > 2 || minutes.length > 2 || hour > 23 || minute > 59)
  {
    return null;
  }

  return hour * 60 + minute;
}

// Adds the colon, pads hours 3-9, refuses bad keys; deleting the colon drops the last hour digit.
class TimeTypingFormatter extends TextInputFormatter
{
  const TimeTypingFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue)
  {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    final bool deleting = oldValue.selection.isCollapsed && newValue.text.length < oldValue.text.length;

    if (deleting)
    {
      if (oldValue.text.endsWith(':') && !newValue.text.contains(':') && digits.isNotEmpty)
      {
        digits = digits.substring(0, digits.length - 1);
      }
    }
    else
    {
      if (digits.isNotEmpty && int.parse(digits[0]) > 2)
      {
        digits = '0$digits';
      }

      final bool badHour = digits.length >= 2 && int.parse(digits.substring(0, 2)) > 23;
      final bool badMinutes = digits.length >= 3 && int.parse(digits[2]) > 5;

      if (digits.length > 4 || badHour || badMinutes)
      {
        return oldValue;
      }
    }

    final String text = digits.length < 2 || (deleting && digits.length == 2)
        ? digits
        : '${digits.substring(0, 2)}:${digits.substring(2)}';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

int snapTypedTime(int minutes, {required int min, required int max})
{
  final int snapped = (minutes / kQuarterHour).round() * kQuarterHour;

  return snapped.clamp(min, max);
}

class MobileTimeField extends StatefulWidget
{
  final String label;

  final int minutes;
  final int min;
  final int max;

  final ValueChanged<int> onChanged;

  const MobileTimeField({
    super.key,
    required this.label,
    required this.minutes,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<MobileTimeField> createState() => _MobileTimeFieldState();
}

class _MobileTimeFieldState extends State<MobileTimeField>
{
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool _typing = false;

  // Text when typing began; leaving it unchanged changes nothing.
  String _initial = '';

  Timer? _repeat;

  @override
  void initState()
  {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(MobileTimeField oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    // Carried by the other end while untouched, e.g. as focus came here from it.
    if (_typing && _controller.text == _initial && widget.minutes != oldWidget.minutes)
    {
      _selectShown();
    }
  }

  @override
  void dispose()
  {
    _repeat?.cancel();
    _focus.dispose();
    _controller.dispose();

    super.dispose();
  }

  String get _shown => formatTimeOfDayShort(timeOfDayFromMinutes(widget.minutes));

  void _step(int delta)
  {
    final int next = (widget.minutes + delta).clamp(widget.min, widget.max);

    if (next == widget.minutes)
    {
      _stopRepeat();

      return;
    }

    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  void _startRepeat(int delta)
  {
    _step(delta);

    _repeat = Timer(_repeatAfter, ()
    {
      _repeat = Timer.periodic(_repeatEvery, (_) => _step(delta));
    });
  }

  void _stopRepeat()
  {
    _repeat?.cancel();
    _repeat = null;
  }

  void _selectShown()
  {
    _initial = _shown;
    _controller
      ..text = _initial
      ..selection = TextSelection(baseOffset: 0, extentOffset: _initial.length);
  }

  void _startTyping()
  {
    _selectShown();

    setState(() => _typing = true);
    _focus.requestFocus();
  }

  // Leaving the field is confirming it: a tap outside, or the keyboard's done.
  void _onFocus()
  {
    if (_focus.hasFocus || !_typing)
    {
      return;
    }

    final int? typed = _controller.text == _initial ? null : parseTypedTime(_controller.text);

    setState(() => _typing = false);

    if (typed == null)
    {
      return;
    }

    final int next = snapTypedTime(typed, min: widget.min, max: widget.max);

    if (next != widget.minutes)
    {
      widget.onChanged(next);
    }
  }

  TextStyle get _valueStyle => GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppTheme.trialInk,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  Widget _buildValue()
  {
    if (_typing)
    {
      return TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: const [TimeTypingFormatter()],
        style: _valueStyle,
        cursorColor: AppTheme.trialTealDeep,
        decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
        onSubmitted: (_) => _focus.unfocus(),
        onTapOutside: (_) => _focus.unfocus(),
      );
    }

    // Shared tap region: moving between times keeps the keyboard up instead of bouncing the sheet.
    return TextFieldTapRegion(
      child: Semantics(
        button: true,
        label: '${widget.label} $_shown',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _startTyping,
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(_shown, style: _valueStyle)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: MobilePalette.mutedText,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: _height),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: _typing ? AppTheme.trialTealDeep : AppTheme.trialInk.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                enabled: widget.minutes > widget.min,
                onDown: () => _startRepeat(-kQuarterHour),
                onUp: _stopRepeat,
              ),
              Expanded(child: _buildValue()),
              _StepButton(
                icon: Icons.add_rounded,
                enabled: widget.minutes < widget.max,
                onDown: () => _startRepeat(kQuarterHour),
                onUp: _stopRepeat,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget
{
  final IconData icon;
  final bool enabled;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => onDown() : null,
        onTapUp: (_) => onUp(),
        onTapCancel: onUp,
        child: SizedBox(
          width: _buttonSize,
          height: _buttonSize,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppTheme.trialTealDeep : AppTheme.trialInk.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}
