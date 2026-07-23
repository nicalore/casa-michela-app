import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

const Color _avatarBackground = Color(0xFFE8EEF7);
const Color _rowLabelColor = Color(0xFF7A7A7A);
const Color _rowValueColor = Color(0xFF2A2A2A);
const Color _sectionDivider = Color(0xFFF1F5F9);

const double _avatarSize = 90;
const double _cardRadius = 40;
const double _cardPadding = 32;
const double _rowGap = 16;

/// Placeholder shown wherever a value is missing.
const String missingValue = '-';

/// Trims and falls back to [missingValue], so a field made of spaces reads as
/// absent rather than blank.
String orDash(String? value)
{
  final trimmed = value?.trim();

  return trimmed == null || trimmed.isEmpty ? missingValue : trimmed;
}

/// One label and value pair inside a [PersonDetailCard].
class DetailRowData
{
  final String label;
  final String value;

  /// Renders the value masked with a reveal toggle. Used for the fields that
  /// should not be readable by anyone glancing at the screen.
  final bool isSensitive;

  const DetailRowData(this.label, this.value, {this.isSensitive = false});
}

// Side by side above the breakpoint, stacked below it. The two cards are
// stretched to equal height, so a short one does not look truncated next to a
// tall one.
//
// The LayoutBuilder stays outside IntrinsicHeight and must never end up inside
// it: intrinsic measurement cannot resolve a LayoutBuilder and throws.
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

/// White panel listing label and value pairs, with a circular icon and a title.
class PersonDetailCard extends StatelessWidget
{
  final String title;
  final IconData icon;

  /// A null entry renders as an invisible row: it pads the shorter card so the
  /// visible rows of two cards side by side stay on the same lines.
  final List<DetailRowData?> rows;

  /// Width of the label column. Cards with long labels need more room, and the
  /// two halves of a pair usually differ.
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
          opacity: 0.0,
          child: _DetailRow(
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
        row = _DetailRow(
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
    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(_cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _avatarSize,
              child: Row(
                children: [
                  _DetailAvatar(icon: icon),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Divider(height: 1, thickness: 1, color: _sectionDivider),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildRows(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailAvatar extends StatelessWidget
{
  final IconData icon;

  const _DetailAvatar({required this.icon});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: const BoxDecoration(color: _avatarBackground, shape: BoxShape.circle),
      child: Icon(icon, size: 44, color: AppTheme.primary),
    );
  }
}

// Fixed width label plus an expanding value. Deliberately no LayoutBuilder here:
// it would conflict with the IntrinsicHeight in PersonDetailCardPair, and the
// pair already guarantees enough width before two cards sit side by side.
class _DetailRow extends StatelessWidget
{
  final String label;
  final String value;
  final double labelWidth;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.labelWidth,
  });

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _rowLabelColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _rowValueColor,
            ),
          ),
        ),
      ],
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

    return Row(
      children: [
        SizedBox(
          width: widget.labelWidth,
          child: Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _rowLabelColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            displayValue,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _rowValueColor,
              letterSpacing: (_hasValue && !_isVisible) ? 3 : 0,
            ),
          ),
        ),
        if (_hasValue)
          IconButton(
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
              color: AppTheme.secondaryText,
            ),
          ),
      ],
    );
  }
}