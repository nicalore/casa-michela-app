import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/theme/app_theme.dart';
import 'notice_embeds.dart';
import 'notice_markdown.dart';

const double _fontSize = 16;
const double _lineHeight = 1.55;

// Each line is a Markdown paragraph, so each gets the email's paragraph gap.
const VerticalSpacing _paragraphGap = VerticalSpacing(0, 10);

const VerticalSpacing _headingGap = VerticalSpacing(6, 8);
const VerticalSpacing _listLineGap = VerticalSpacing(0, 4);
const VerticalSpacing _quoteLineGap = VerticalSpacing(2, 2);

// The registered family has every weight; a google_fonts family holds only one.
TextStyle noticeTextStyle({
  double fontSize = _fontSize,
  FontWeight fontWeight = FontWeight.w500,
  double height = _lineHeight,
})
{
  return TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    color: AppTheme.trialInk,
  );
}

DefaultTextBlockStyle _block(TextStyle style, VerticalSpacing spacing, [BoxDecoration? decoration])
{
  return DefaultTextBlockStyle(style, HorizontalSpacing.zero, spacing, VerticalSpacing.zero, decoration);
}

// Headings grow from the text's own size, so a smaller text keeps them in step.
DefaultTextBlockStyle _heading(TextStyle text, double size)
{
  return _block(
    text.copyWith(
      fontSize: size * text.fontSize! / _fontSize,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: AppTheme.trialOcean,
    ),
    _headingGap,
  );
}

DefaultStyles noticeStyles([TextStyle? textStyle])
{
  final TextStyle text = textStyle ?? noticeTextStyle();
  // Bold must stand out from a text already set heavier than usual.
  final FontWeight bold = text.fontWeight!.value >= FontWeight.w600.value ? FontWeight.w800 : FontWeight.w700;

  return DefaultStyles(
    paragraph: _block(text, _paragraphGap),
    h1: _heading(text, 22),
    h2: _heading(text, 19),
    h3: _heading(text, 17),
    bold: TextStyle(fontWeight: bold),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
    link: const TextStyle(
      color: AppTheme.trialTealDeep,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppTheme.trialTealDeep,
    ),
    lists: DefaultListBlockStyle(text, HorizontalSpacing.zero, _paragraphGap, _listLineGap, null, null),
    // Bullets and numbers in the text's own family, whatever the theme around.
    leading: _block(text, VerticalSpacing.zero),
    quote: DefaultTextBlockStyle(
      text.copyWith(color: AppTheme.trialMutedText),
      const HorizontalSpacing(14, 0),
      _paragraphGap,
      _quoteLineGap,
      const BoxDecoration(border: Border(left: BorderSide(width: 3, color: AppTheme.trialLine))),
    ),
    placeHolder: _block(text.copyWith(color: AppTheme.trialMutedText.withValues(alpha: 0.7)), VerticalSpacing.zero),
  );
}

// Quill's link menu asks for its own words; the app installs no delegate for them.
class NoticeQuillLocalizations extends StatelessWidget
{
  final Widget child;

  const NoticeQuillLocalizations({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return Localizations.override(
      context: context,
      locale: const Locale('it'),
      delegates: const [FlutterQuillLocalizations.delegate],
      child: child,
    );
  }
}

// Room the last block leaves under itself, which a reader in a list does not want.
double _trailingGap(Document document)
{
  final Node? last = document.root.children.lastOrNull;

  if (last is Block)
  {
    final Map<String, Attribute> attributes = last.style.attributes;

    if (attributes.containsKey(Attribute.list.key))
    {
      return _paragraphGap.bottom + _listLineGap.bottom;
    }

    if (attributes.containsKey(Attribute.blockQuote.key))
    {
      return _paragraphGap.bottom + _quoteLineGap.bottom;
    }
  }

  if (last is Line && last.style.attributes.containsKey(Attribute.header.key))
  {
    return _headingGap.bottom;
  }

  return _paragraphGap.bottom;
}

class NoticeMessageView extends StatefulWidget
{
  final String message;
  final NoticeImages images;

  // Null keeps the notices' own text.
  final TextStyle? textStyle;

  // True ends the view with the last line, as a plain text would.
  final bool tight;

  const NoticeMessageView({
    super.key,
    required this.message,
    required this.images,
    this.textStyle,
    this.tight = false,
  });

  @override
  State<NoticeMessageView> createState() => _NoticeMessageViewState();
}

class _NoticeMessageViewState extends State<NoticeMessageView>
{
  late final QuillController _controller = QuillController(
    document: noticeDocument(widget.message),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );

  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose()
  {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget view = NoticeQuillLocalizations(
      child: QuillEditor(
        controller: _controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          scrollable: false,
          showCursor: false,
          customStyles: noticeStyles(widget.textStyle),
          embedBuilders: [NoticeImageEmbedBuilder(widget.images), const NoticeDividerEmbedBuilder()],
        ),
      ),
    );

    return widget.tight ? _TrimmedBottom(trim: _trailingGap(_controller.document), child: view) : view;
  }
}

// Lays the child out whole but claims less height: what is cut is empty room.
class _TrimmedBottom extends SingleChildRenderObjectWidget
{
  final double trim;

  const _TrimmedBottom({required this.trim, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTrimmedBottom(trim);

  @override
  void updateRenderObject(BuildContext context, _RenderTrimmedBottom renderObject) => renderObject.trim = trim;
}

class _RenderTrimmedBottom extends RenderProxyBox
{
  _RenderTrimmedBottom(this._trim);

  double _trim;

  set trim(double value)
  {
    if (value != _trim)
    {
      _trim = value;
      markNeedsLayout();
    }
  }

  BoxConstraints _whole(BoxConstraints constraints)
  {
    return constraints.copyWith(minHeight: 0, maxHeight: constraints.maxHeight + _trim);
  }

  Size _trimmed(BoxConstraints constraints, Size whole)
  {
    return constraints.constrain(Size(whole.width, math.max(0, whole.height - _trim)));
  }

  @override
  void performLayout()
  {
    final RenderBox box = child!;

    box.layout(_whole(constraints), parentUsesSize: true);
    size = _trimmed(constraints, box.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _trimmed(constraints, child!.getDryLayout(_whole(constraints)));

  @override
  double computeMinIntrinsicHeight(double width) => math.max(0, super.computeMinIntrinsicHeight(width) - _trim);

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(0, super.computeMaxIntrinsicHeight(width) - _trim);
}
