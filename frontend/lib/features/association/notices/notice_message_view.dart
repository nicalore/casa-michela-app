import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/theme/app_theme.dart';
import 'notice_embeds.dart';
import 'notice_markdown.dart';

const double _fontSize = 16;
const double _lineHeight = 1.55;

// Each line is a Markdown paragraph, so each gets the email's paragraph gap.
const VerticalSpacing _paragraphGap = VerticalSpacing(0, 10);

// The registered family has every weight; a google_fonts family holds only one.
TextStyle noticeTextStyle()
{
  return const TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: _fontSize,
    fontWeight: FontWeight.w500,
    height: _lineHeight,
    color: AppTheme.trialInk,
  );
}

DefaultTextBlockStyle _block(TextStyle style, VerticalSpacing spacing, [BoxDecoration? decoration])
{
  return DefaultTextBlockStyle(style, HorizontalSpacing.zero, spacing, VerticalSpacing.zero, decoration);
}

DefaultTextBlockStyle _heading(double size)
{
  return _block(
    noticeTextStyle().copyWith(fontSize: size, fontWeight: FontWeight.w700, height: 1.3, color: AppTheme.trialOcean),
    const VerticalSpacing(6, 8),
  );
}

DefaultStyles noticeStyles()
{
  final TextStyle text = noticeTextStyle();

  return DefaultStyles(
    paragraph: _block(text, _paragraphGap),
    h1: _heading(22),
    h2: _heading(19),
    h3: _heading(17),
    bold: const TextStyle(fontWeight: FontWeight.w700),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
    link: const TextStyle(
      color: AppTheme.trialTealDeep,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppTheme.trialTealDeep,
    ),
    lists: DefaultListBlockStyle(text, HorizontalSpacing.zero, _paragraphGap, const VerticalSpacing(0, 4), null, null),
    quote: DefaultTextBlockStyle(
      text.copyWith(color: AppTheme.trialMutedText),
      const HorizontalSpacing(14, 0),
      _paragraphGap,
      const VerticalSpacing(2, 2),
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

// A sent message as its readers see it.
class NoticeMessageView extends StatefulWidget
{
  final String message;
  final NoticeImages images;

  const NoticeMessageView({super.key, required this.message, required this.images});

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
    return NoticeQuillLocalizations(
      child: QuillEditor(
        controller: _controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          scrollable: false,
          showCursor: false,
          customStyles: noticeStyles(),
          embedBuilders: [NoticeImageEmbedBuilder(widget.images), const NoticeDividerEmbedBuilder()],
        ),
      ),
    );
  }
}
