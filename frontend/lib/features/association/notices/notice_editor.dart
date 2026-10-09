import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/snackbar.dart';
import 'notice_embeds.dart';
import 'notice_item.dart';
import 'notice_markdown.dart';
import 'notice_message_view.dart';
import 'notice_strings.dart';

const double _radius = 14;
const double _borderWidth = 2;
const double _focusRingWidth = 4;
const double _focusRingOpacity = 0.15;
const Color _surface = Color(0xFFFBFDFC);

const double _toolSize = 36;
const double _toolHeight = 34;
const double _toolIconSize = 21;
const double _headingMenuWidth = 170;

// A photo is shrunk before it travels: it counts toward the 15 MB of the email.
const double _photoMaxSide = 1600;
const int _photoQuality = 85;

// Markdown has no underline: the shortcut would format what never reaches anyone.
const Map<ShortcutActivator, Intent> _noUnderline = {
  SingleActivator(LogicalKeyboardKey.keyU, control: true): DoNothingAndStopPropagationTextIntent(),
  SingleActivator(LogicalKeyboardKey.keyU, meta: true): DoNothingAndStopPropagationTextIntent(),
};

class NoticeEditor extends StatefulWidget
{
  final QuillController controller;
  final NoticeImages images;
  final double height;
  // False refuses the photo: the composer knows what the files weigh.
  final bool Function(int bytes) canAdd;

  const NoticeEditor({
    super.key,
    required this.controller,
    required this.images,
    required this.height,
    required this.canAdd,
  });

  @override
  State<NoticeEditor> createState() => _NoticeEditorState();
}

class _NoticeEditorState extends State<NoticeEditor>
{
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  QuillController get _controller => widget.controller;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_onFocus);
  }

  @override
  void dispose()
  {
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  Map<String, Attribute> get _style => _controller.getSelectionStyle().attributes;

  bool _isOn(Attribute attribute) => _style[attribute.key]?.value == attribute.value;

  void _toggle(Attribute attribute)
  {
    _controller.formatSelection(_isOn(attribute) ? Attribute.clone(attribute, null) : attribute);
    _focusNode.requestFocus();
  }

  void _setHeading(Attribute? heading)
  {
    _controller.formatSelection(heading ?? Attribute.clone(Attribute.header, null));
    _focusNode.requestFocus();
  }

  void _insertBlock(Object embed)
  {
    final TextSelection selection = _controller.selection;
    final int index = selection.start;

    _controller.replaceText(
      index,
      selection.end - index,
      embed,
      TextSelection.collapsed(offset: index + 1),
    );
    _focusNode.requestFocus();
  }

  Future<void> _insertPhoto() async
  {
    final XFile? photo;

    try
    {
      photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _photoMaxSide,
        maxHeight: _photoMaxSide,
        imageQuality: _photoQuality,
      );
    }
    catch (_)
    {
      return;
    }

    if (photo == null || !mounted)
    {
      return;
    }

    final Uint8List bytes = await photo.readAsBytes();

    if (!mounted || !widget.canAdd(bytes.length))
    {
      return;
    }

    // Decoded first: the line it lands on does not grow under the cursor.
    await precacheImage(MemoryImage(bytes), context);

    if (!mounted)
    {
      return;
    }

    final String key = newImageKey();

    widget.images.added[key] = NoticeUpload(
      fileName: key,
      bytes: bytes,
      mimeType: photo.mimeType ?? 'image/jpeg',
    );
    _insertBlock(BlockEmbed.image('$kNoticeImageScheme$key'));
  }

  Future<void> _insertLink() async
  {
    final TextSelection selection = _controller.selection;
    final String? address = await showBlurredDialog<String>(
      context: context,
      barrierLabel: 'NoticeLink',
      builder: (_) => const _LinkDialog(),
    );

    if (address == null)
    {
      return;
    }

    final Attribute link = LinkAttribute(address);

    if (selection.isCollapsed)
    {
      _controller.replaceText(selection.start, 0, address, null);
      _controller.formatText(selection.start, address.length, link);
    }
    else
    {
      _controller.formatText(selection.start, selection.end - selection.start, link);
    }

    _focusNode.requestFocus();
  }

  Widget _buildHeadingMenu()
  {
    final Object? level = _style[Attribute.header.key]?.value;
    final int current = level is int && (level == 2 || level == 3) ? level : 0;

    return AppMenuButton<int>(
      value: current,
      menuWidth: _headingMenuWidth,
      options: const [
        FilterOption(value: 0, label: kTextStyle),
        FilterOption(value: 2, label: kHeadingStyle),
        FilterOption(value: 3, label: kSubheadingStyle),
      ],
      onChanged: (value) => _setHeading(switch (value)
      {
        2 => Attribute.h2,
        3 => Attribute.h3,
        _ => null,
      }),
      builder: (context, marked) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: _toolHeight,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: marked ? AppTheme.trialGoldSurface : Colors.white,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              switch (current)
              {
                2 => kHeadingStyle,
                3 => kSubheadingStyle,
                _ => kTextStyle,
              },
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: marked ? AppTheme.trialTealDeep : AppTheme.trialInk,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: marked ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _separator()
  {
    return Container(
      width: 1.5,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppTheme.trialLine,
    );
  }

  Widget _buildToolbar()
  {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppTheme.trialLine, width: 1.5)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildHeadingMenu(),
            _separator(),
            _Tool(Icons.format_bold_rounded, kBoldTip, on: _isOn(Attribute.bold), onTap: () => _toggle(Attribute.bold)),
            _Tool(Icons.format_italic_rounded, kItalicTip, on: _isOn(Attribute.italic), onTap: () => _toggle(Attribute.italic)),
            _Tool(
              Icons.format_strikethrough_rounded,
              kStrikeTip,
              on: _isOn(Attribute.strikeThrough),
              onTap: () => _toggle(Attribute.strikeThrough),
            ),
            _separator(),
            _Tool(Icons.format_list_bulleted_rounded, kBulletsTip, on: _isOn(Attribute.ul), onTap: () => _toggle(Attribute.ul)),
            _Tool(Icons.format_list_numbered_rounded, kNumbersTip, on: _isOn(Attribute.ol), onTap: () => _toggle(Attribute.ol)),
            _Tool(Icons.format_quote_rounded, kQuoteTip, on: _isOn(Attribute.blockQuote), onTap: () => _toggle(Attribute.blockQuote)),
            _separator(),
            _Tool(Icons.link_rounded, kLinkTip, on: _style.containsKey(Attribute.link.key), onTap: _insertLink),
            _Tool(Icons.image_rounded, kImageTip, onTap: _insertPhoto),
            _Tool(Icons.horizontal_rule_rounded, kDividerTip, onTap: () => _insertBlock(kNoticeDivider)),
            _separator(),
            _Tool(Icons.undo_rounded, kUndoTip, enabled: _controller.hasUndo, onTap: _controller.undo),
            _Tool(Icons.redo_rounded, kRedoTip, enabled: _controller.hasRedo, onTap: _controller.redo),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool lit = _focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: lit ? AppTheme.trialGold : AppTheme.trialLine, width: _borderWidth),
        boxShadow: [
          BoxShadow(
            color: AppTheme.trialGold.withValues(alpha: lit ? _focusRingOpacity : 0),
            spreadRadius: _focusRingWidth,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius - _borderWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(),
            SizedBox(
              height: widget.height,
              child: NoticeQuillLocalizations(
                child: QuillEditor(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    customStyles: noticeStyles(),
                    customShortcuts: _noUnderline,
                    embedBuilders: [NoticeImageEmbedBuilder(widget.images), const NoticeDividerEmbedBuilder()],
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

class _Tool extends StatefulWidget
{
  final IconData icon;
  final String tip;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;

  const _Tool(this.icon, this.tip, {required this.onTap, this.on = false, this.enabled = true});

  @override
  State<_Tool> createState() => _ToolState();
}

class _ToolState extends State<_Tool>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool lit = widget.enabled && (widget.on || _hover);
    final Color color = !widget.enabled
        ? AppTheme.trialMutedText.withValues(alpha: 0.4)
        : widget.on ? AppTheme.modifiedAccent : _hover ? AppTheme.trialTealDeep : AppTheme.trialMutedText;

    return Tooltip(
      message: widget.tip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: Container(
            width: _toolSize,
            height: _toolHeight,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: lit ? AppTheme.trialGoldSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(widget.icon, size: _toolIconSize, color: color),
          ),
        ),
      ),
    );
  }
}

class _LinkDialog extends StatefulWidget
{
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog>
{
  final TextEditingController _address = TextEditingController();

  @override
  void dispose()
  {
    _address.dispose();
    super.dispose();
  }

  void _confirm()
  {
    final String address = _address.text.trim();

    if (address.isEmpty)
    {
      CustomSnackBar.show(context: context, message: kLinkInvalid, isError: true);

      return;
    }

    final bool hasScheme = address.startsWith('http://') || address.startsWith('https://') || address.startsWith('mailto:');

    Navigator.of(context).pop(hasScheme ? address : 'https://$address');
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kLinkEyebrow,
      title: kLinkTitle,
      maxWidth: 520,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kLinkConfirm,
          icon: Icons.check_rounded,
          height: 52,
          fontSize: 14,
          onPressed: _confirm,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: AppTextField(
            controller: _address,
            label: kLinkAddressLabel,
            hintText: kLinkAddressHint,
            nothingAbove: true,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _confirm(),
          ),
        ),
      ],
    );
  }
}
