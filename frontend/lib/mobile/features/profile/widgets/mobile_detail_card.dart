import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';

const double _radius = 22;
const EdgeInsets _padding = EdgeInsets.fromLTRB(16, 14, 16, 16);

const double _badgeSize = 34;
const double _badgeIconSize = 19;
const double _editSize = 38;

const double _headGap = 8;
const double _rowPadding = 9;

class MobileDetailCard extends StatelessWidget
{
  final IconData icon;
  final String title;
  final String? eyebrow;

  final List<DetailRowData> rows;

  // Replaces the rows for content that does not read as label and value.
  final Widget? body;

  final Widget? notice;

  final VoidCallback? onEdit;
  final String? editLabel;

  // Replaces the pencil, e.g. the statistics' spinner.
  final Widget? trailing;

  const MobileDetailCard({
    super.key,
    required this.icon,
    required this.title,
    this.eyebrow,
    this.rows = const [],
    this.body,
    this.notice,
    this.onEdit,
    this.editLabel,
    this.trailing,
  });

  // Drops the desktop card's blank rows, which only pad the shorter card of a pair.
  factory MobileDetailCard.of(
    PersonDetailCard card, {
    VoidCallback? onEdit,
    String? editLabel,
  })
  {
    return MobileDetailCard(
      icon: card.icon,
      title: card.title,
      rows: card.rows.whereType<DetailRowData>().toList(),
      onEdit: onEdit,
      editLabel: editLabel,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? onEdit = this.onEdit;

    return MobileGlassPanel(
      padding: _padding,
      borderRadius: const BorderRadius.all(Radius.circular(_radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileCardHead(
            icon: icon,
            title: title,
            eyebrow: eyebrow,
            trailing: onEdit != null
                ? _EditButton(label: editLabel ?? title, onTap: onEdit)
                : trailing,
          ),
          const SizedBox(height: _headGap),
          ?notice,
          body ?? MobileDetailRows(rows: rows),
        ],
      ),
    );
  }
}

class MobileCardHead extends StatelessWidget
{
  final IconData icon;
  final String title;
  final String? eyebrow;
  final Widget? trailing;

  final Color tint;

  const MobileCardHead({
    super.key,
    required this.icon,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.tint = AppTheme.trialTealDeep,
  });

  @override
  Widget build(BuildContext context)
  {
    final String? eyebrow = this.eyebrow;
    final Widget? trailing = this.trailing;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _editSize),
      child: Row(
        children: [
          MobileCardBadge(icon: icon, tint: tint),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      eyebrow.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppTheme.trialTealDeep,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trialInk,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing,
          ],
        ],
      ),
    );
  }
}

class MobileCardBadge extends StatelessWidget
{
  final IconData icon;
  final Color tint;

  const MobileCardBadge({super.key, required this.icon, this.tint = AppTheme.trialTealDeep});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.13),
      ),
      child: Icon(icon, size: _badgeIconSize, color: tint),
    );
  }
}

// Label above value, so long values never wrap beside a label at any text size.
class MobileDetailRows extends StatelessWidget
{
  final List<DetailRowData> rows;

  const MobileDetailRows({super.key, required this.rows});

  // Padding included, so the whole row answers.
  static Widget _tappable(VoidCallback? onTap, Widget row)
  {
    if (onTap == null)
    {
      return row;
    }

    return Semantics(
      button: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          _tappable(
            rows[i].onTap,
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.09))),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: i == 0 ? 2 : _rowPadding, bottom: _rowPadding),
                child: _Row(data: rows[i]),
              ),
            ),
          ),
      ],
    );
  }
}

TextStyle mobileFactLabelStyle()
{
  return GoogleFonts.plusJakartaSans(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: MobilePalette.mutedText,
  );
}

TextStyle mobileFactValueStyle()
{
  return GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppTheme.trialInk,
  );
}

class _Row extends StatelessWidget
{
  final DetailRowData data;

  const _Row({required this.data});

  @override
  Widget build(BuildContext context)
  {
    final Widget value = data.valueWidget ??
        (data.isSensitive
            ? _HiddenValue(value: data.value, hidesLength: data.hidesLength)
            : Text(data.value, style: mobileFactValueStyle()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data.label, style: mobileFactLabelStyle()),
        const SizedBox(height: 2),
        value,
      ],
    );
  }
}

// Masked until tapped, as on the desktop.
class _HiddenValue extends StatefulWidget
{
  final String value;
  final bool hidesLength;

  const _HiddenValue({required this.value, required this.hidesLength});

  @override
  State<_HiddenValue> createState() => _HiddenValueState();
}

class _HiddenValueState extends State<_HiddenValue>
{
  bool _shown = false;

  @override
  Widget build(BuildContext context)
  {
    final String masked = widget.hidesLength ? kObscuredValue : '•' * widget.value.length;

    return Row(
      children: [
        Expanded(
          child: Text(
            _shown ? widget.value : masked,
            style: _shown
                ? mobileFactValueStyle()
                : mobileFactValueStyle().copyWith(letterSpacing: kObscuredLetterSpacing),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _shown = !_shown),
          icon: Icon(
            _shown ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 21,
            color: MobilePalette.mutedText,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget
{
  final String label;
  final VoidCallback onTap;

  const _EditButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _editSize,
          height: _editSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.85),
            border: Border.all(color: AppTheme.trialOcean.withValues(alpha: 0.13)),
          ),
          child: const Icon(Icons.edit_rounded, size: 19, color: AppTheme.trialTealDeep),
        ),
      ),
    );
  }
}
