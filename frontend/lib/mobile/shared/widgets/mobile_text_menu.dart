import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

const MethodChannel _channel = MethodChannel('it.casamichela.app/text_menu');

bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

// Every text field's contextMenuBuilder: the system's menu wherever one can be had.
Widget mobileTextMenu(BuildContext context, EditableTextState field)
{
  if (SystemContextMenu.isSupportedByField(field))
  {
    return SystemContextMenu.editableText(editableTextState: field);
  }

  if (_isAndroid)
  {
    return _AndroidTextMenu(
      items: field.contextMenuButtonItems,
      anchors: () => field.contextMenuAnchors,
      onClosed: () => field.hideToolbar(false),
    );
  }

  return AdaptiveTextSelectionToolbar.editableText(editableTextState: field);
}

// Quill has no EditableTextState, which is what iOS's menu is reached through.
Widget mobileQuillTextMenu(BuildContext context, QuillRawEditorState editor)
{
  if (_isAndroid)
  {
    return _AndroidTextMenu(
      items: editor.contextMenuButtonItems,
      anchors: () => editor.contextMenuAnchors,
      onClosed: () => editor.hideToolbar(false),
    );
  }

  return QuillRawEditorConfig.defaultContextMenuBuilder(context, editor);
}

class _AndroidTextMenu extends StatefulWidget
{
  final List<ContextMenuButtonItem> items;
  final ValueGetter<TextSelectionToolbarAnchors> anchors;
  final VoidCallback onClosed;

  // Custom items are the ones other apps add, like translate or read aloud.
  _AndroidTextMenu({required List<ContextMenuButtonItem> items, required this.anchors, required this.onClosed})
      : items = [
          for (final ContextMenuButtonItem item in items)
            if (item.type != ContextMenuButtonType.custom) item,
        ];

  @override
  State<_AndroidTextMenu> createState() => _AndroidTextMenuState();
}

class _AndroidTextMenuState extends State<_AndroidTextMenu>
{
  // The system keeps one menu: a new one takes it over before the old one is disposed.
  static _AndroidTextMenuState? _current;

  List<String> _labels = const [];
  double _scale = 1;

  List<String> _sentLabels = const [];
  Rect? _sentAnchor;

  static Future<void> _fromSystem(MethodCall call) async
  {
    final _AndroidTextMenu? menu = _current?.widget;

    switch (call.method)
    {
      case 'pressed':
        menu?.items.elementAtOrNull(call.arguments as int)?.onPressed?.call();
      case 'closed':
        menu?.onClosed();
    }
  }

  @override
  void initState()
  {
    super.initState();
    _current = this;
    _channel.setMethodCallHandler(_fromSystem);
    _sendAfterFrame();
  }

  @override
  void dispose()
  {
    if (identical(_current, this))
    {
      _current = null;
      _channel.invokeMethod<void>('hide');
    }

    super.dispose();
  }

  // The text can move under a menu Flutter doesn't place; this asks for no frames of its own.
  void _sendAfterFrame()
  {
    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        _send();
        _sendAfterFrame();
      }
    });
  }

  void _send()
  {
    final TextSelectionToolbarAnchors anchors = widget.anchors();
    final Offset top = anchors.primaryAnchor;
    final Offset bottom = anchors.secondaryAnchor ?? top;
    final Rect anchor = Rect.fromPoints(top, bottom + const Offset(0, TextSelectionToolbar.kHandleSize));

    if (listEquals(_labels, _sentLabels) && anchor == _sentAnchor)
    {
      return;
    }

    _sentLabels = _labels;
    _sentAnchor = anchor;

    // Empty until the clipboard has answered whether Paste belongs in the list.
    if (_labels.isEmpty)
    {
      _channel.invokeMethod<void>('hide');
      return;
    }

    _channel.invokeMethod<void>('show', {
      'labels': _labels,
      'left': anchor.left * _scale,
      'top': anchor.top * _scale,
      'right': anchor.right * _scale,
      'bottom': anchor.bottom * _scale,
    });
  }

  @override
  Widget build(BuildContext context)
  {
    _labels = [
      for (final ContextMenuButtonItem item in widget.items)
        AdaptiveTextSelectionToolbar.getButtonLabel(context, item),
    ];
    _scale = MediaQuery.devicePixelRatioOf(context);

    return const SizedBox.shrink();
  }
}
