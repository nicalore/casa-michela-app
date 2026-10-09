import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import 'notice_format.dart';
import 'notice_item.dart';
import 'notice_strings.dart';

const double _chipHeight = 44;
const double _chipRadius = 12;
const double _badgeSize = 28;
const Color _chipSurface = Color(0xFFF5FAF9);
const Duration _hoverFade = Duration(milliseconds: 180);
const Color _dashColor = Color(0xFF9FC9C3);

class NoticeFileChip extends StatefulWidget
{
  final String fileName;
  final int size;
  // A sent file downloads from the whole chip; a chosen one is removed by its x alone.
  final VoidCallback? onDownload;
  final VoidCallback? onRemove;

  const NoticeFileChip({
    super.key,
    required this.fileName,
    required this.size,
    this.onDownload,
    this.onRemove,
  });

  @override
  State<NoticeFileChip> createState() => _NoticeFileChipState();
}

class _NoticeFileChipState extends State<NoticeFileChip>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final NoticeFileKind kind = NoticeFileKind.of(widget.fileName);
    final VoidCallback? onDownload = widget.onDownload;
    final VoidCallback? onRemove = widget.onRemove;
    final bool lit = _hover && onDownload != null;

    final Widget chip = AnimatedContainer(
      duration: _hoverFade,
      curve: Curves.easeOut,
      height: _chipHeight,
      padding: EdgeInsets.only(left: 8, right: onRemove != null ? 4 : 12),
      decoration: BoxDecoration(
        // Opaque ends: a translucent hover lerp flashes dark midway.
        color: lit ? AppTheme.trialGoldSurface : _chipSurface,
        borderRadius: BorderRadius.circular(_chipRadius),
        border: Border.all(color: lit ? AppTheme.trialGold : AppTheme.trialLine, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _badgeSize,
            height: _badgeSize,
            decoration: BoxDecoration(color: kind.color, borderRadius: BorderRadius.circular(8)),
            child: Icon(kind.icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.trialInk),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            fileSizeLabel(widget.size),
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
          ),
          const SizedBox(width: 6),
          if (onRemove != null)
            FadeHoverIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.trialDanger,
              hoverColor: AppTheme.trialGoldSurface,
              onTap: onRemove,
            )
          else
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: lit ? AppTheme.trialTealDeep : AppTheme.trialMutedText),
              duration: _hoverFade,
              curve: Curves.easeOut,
              builder: (context, color, _) => Icon(Icons.download_rounded, size: 19, color: color),
            ),
        ],
      ),
    );

    if (onDownload == null)
    {
      return chip;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: onDownload, child: chip),
    );
  }
}

// Picks or takes dropped files of any kind, read whole.
class NoticeDropZone extends StatefulWidget
{
  final ValueChanged<List<NoticeUpload>> onFiles;

  const NoticeDropZone({super.key, required this.onFiles});

  @override
  State<NoticeDropZone> createState() => _NoticeDropZoneState();
}

class _NoticeDropZoneState extends State<NoticeDropZone>
{
  bool _lit = false;

  void _refuse()
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: kFileUnreadable, isError: true);
    }
  }

  Future<void> _pick() async
  {
    final List<NoticeUpload> files = [];

    try
    {
      for (final file in await FilePicker.pickFiles())
      {
        files.add(NoticeUpload(fileName: file.name, bytes: await file.readAsBytes()));
      }
    }
    catch (_)
    {
      _refuse();

      return;
    }

    if (files.isNotEmpty && mounted)
    {
      widget.onFiles(files);
    }
  }

  Future<void> _drop(DropDoneDetails details) async
  {
    setState(() => _lit = false);

    final List<NoticeUpload> files = [];

    try
    {
      for (final item in details.files)
      {
        files.add(NoticeUpload(fileName: item.name, bytes: await item.readAsBytes(), mimeType: item.mimeType));
      }
    }
    catch (_)
    {
      _refuse();

      return;
    }

    if (files.isNotEmpty && mounted)
    {
      widget.onFiles(files);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final TextStyle strong = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: AppTheme.trialTealDeep,
    );

    return DropTarget(
      onDragEntered: (_) => setState(() => _lit = true),
      onDragExited: (_) => setState(() => _lit = false),
      onDragDone: _drop,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _lit = true),
        onExit: (_) => setState(() => _lit = false),
        child: GestureDetector(
          onTap: _pick,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _lit ? 1 : 0),
            duration: _hoverFade,
            curve: Curves.easeOut,
            builder: (context, t, child) => CustomPaint(
              foregroundPainter: _DashedBorder(color: Color.lerp(_dashColor, AppTheme.trialGold, t)!),
              child: Container(
                height: _chipHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.white, AppTheme.trialGoldSurface, t),
                  borderRadius: BorderRadius.circular(_chipRadius),
                ),
                child: child,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.upload_file_rounded, size: 20, color: AppTheme.trialTealDeep),
                const SizedBox(width: 10),
                Text(kAddFile, style: strong),
                const SizedBox(width: 8),
                Text(
                  kOrDropHere,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter
{
  static const double _dash = 6;
  static const double _gap = 4;

  final Color color;

  const _DashedBorder({required this.color});

  @override
  void paint(Canvas canvas, Size size)
  {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Path outline = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_chipRadius)).deflate(0.75));

    for (final PathMetric metric in outline.computeMetrics())
    {
      for (double start = 0; start < metric.length; start += _dash + _gap)
      {
        canvas.drawPath(metric.extractPath(start, start + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
