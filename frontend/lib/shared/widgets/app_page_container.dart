import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  // Native builds take the viewport as it is: the minimum size below exists to
  // keep the desktop layout intact in a small browser window, and imposing it
  // on a phone would only clip the interface.
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
        final width = math.max(constraints.maxWidth, widget.minWidth);
        final height = math.max(constraints.maxHeight, widget.minHeight);

        // The horizontal scroll view is what makes the minimum width real. A
        // ConstrainedBox cannot enforce it on its own: minWidth is clamped to
        // the width it is handed, so in a window narrower than minWidth the
        // page used to be squeezed into the window instead of keeping its size
        // and scrolling, which is the opposite of what the minimum is for. A
        // scroll view hands its child an unbounded main axis, so the minimum
        // survives and the overflow becomes something you can scroll to.
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
                  child: widget.builder(context, width, height),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // kIsWeb is true in every browser, phones included, so this is not a
  // desktop-versus-mobile switch: on the web build the scrollable branch always
  // wins, and index.html scales it down for touch devices through its virtual
  // viewport. The native branch is reached only by the Android and iOS builds.
  @override
  Widget build(BuildContext context)
  {
    return kIsWeb ? _buildWebLayout() : _buildNativeLayout();
  }
}