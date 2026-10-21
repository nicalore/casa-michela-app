import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';

// Widget tests run with kIsWeb false; this forces the scrolling web container.
@visibleForTesting
bool debugAlwaysUseWebPageLayout = false;

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
        // Narrow windows reflow the page to their width; wider ones keep its least size and scroll to it.
        final bool narrow = AppBreakpoints.isNarrowWidth(constraints.maxWidth);
        final double width = narrow ? constraints.maxWidth : math.max(constraints.maxWidth, widget.minWidth);
        final double height = narrow ? constraints.maxHeight : math.max(constraints.maxHeight, widget.minHeight);

        // The same scroll views at every width: rebuilt at the breakpoint, they would lose their offsets.
        // A ConstrainedBox alone clamps minWidth to the width it is handed; the scroll view's unbounded axis makes it real.
        return Scrollbar(
          controller: _verticalController,
          thumbVisibility: !narrow,
          trackVisibility: !narrow,
          child: SingleChildScrollView(
            controller: _verticalController,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: !narrow,
              trackVisibility: !narrow,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalController,
                physics: narrow ? const NeverScrollableScrollPhysics() : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: width,
                    maxWidth: narrow ? width : double.infinity,
                    minHeight: height,
                  ),
                  child: widget.builder(context, width, height),
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
    return kIsWeb || debugAlwaysUseWebPageLayout ? _buildWebLayout() : _buildNativeLayout();
  }
}