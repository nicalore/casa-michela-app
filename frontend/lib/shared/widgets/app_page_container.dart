import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';

typedef PageContentBuilder = Widget Function(
  BuildContext context,
  double width,
  double height,
);

class AppPageContainer extends StatefulWidget
{
  final PageContentBuilder builder;
  final double minWidth;
  final double minHeight;

  const AppPageContainer({
    super.key,
    required this.builder,
    required this.minWidth,
    required this.minHeight,
  });

  @override
  State<AppPageContainer> createState() => _AppPageContainerState();
}

class _AppPageContainerState extends State<AppPageContainer>
{
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  // The two web layouts use different scroll views: without its own key the page loses its state at the compact breakpoint.
  final GlobalKey _contentKey = GlobalKey();

  Widget _keyed(Widget content) => KeyedSubtree(key: _contentKey, child: content);

  @override
  void dispose()
  {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Widget _buildNativeLayout()
  {
    return LayoutBuilder(
      builder: (context, constraints) => widget.builder(
        context,
        constraints.maxWidth,
        constraints.maxHeight,
      ),
    );
  }

  Widget _buildWebLayout()
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (AppBreakpoints.fromWidth(constraints.maxWidth).isCompact)
        {
          return SingleChildScrollView(
            controller: _verticalController,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _keyed(
                widget.builder(
                  context,
                  constraints.maxWidth,
                  constraints.maxHeight,
                ),
              ),
            ),
          );
        }

        final width = math.max(constraints.maxWidth, widget.minWidth);
        final height = math.max(constraints.maxHeight, widget.minHeight);

        // A ConstrainedBox alone clamps minWidth to the width it is handed; the scroll view's unbounded axis makes it real.
        return Scrollbar(
          controller: _verticalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalController,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalController,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: width, minHeight: height),
                  child: _keyed(widget.builder(context, width, height)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // kIsWeb is true on phones too: web always takes the scrollable branch, only Android/iOS builds reach the native one.
  @override
  Widget build(BuildContext context)
  {
    return kIsWeb ? _buildWebLayout() : _buildNativeLayout();
  }
}