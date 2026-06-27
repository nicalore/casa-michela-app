import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppPageContainer extends StatefulWidget
{
  final Widget Function
  (
    BuildContext context,
    double width,
    double height,
  ) builder;

  final double minWidth;
  final double minHeight;

  const AppPageContainer
  ({
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

  @override
  void dispose()
  {
    //ReleaseResources
    _verticalController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    if (!kIsWeb)
    {
      //NativeMobileLayout
      return LayoutBuilder
      (
        builder: (BuildContext context, BoxConstraints constraints)
        {
          return widget.builder
          (
            context,
            constraints.maxWidth,
            constraints.maxHeight,
          );
        },
      );
    }

    //WebBrowserLayout
    return LayoutBuilder
    (
      builder: (BuildContext context, BoxConstraints constraints)
      {
        final double width = constraints.maxWidth < widget.minWidth
            ? widget.minWidth
            : constraints.maxWidth;

        final double height = constraints.maxHeight < widget.minHeight
            ? widget.minHeight
            : constraints.maxHeight;

        return Scrollbar
        (
          controller: _verticalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView
          (
            controller: _verticalController,
            child: ConstrainedBox
            (
              constraints: BoxConstraints
              (
                minWidth: width,
                minHeight: height,
              ),
              child: widget.builder
              (
                context,
                width,
                height,
              ),
            ),
          ),
        );
      },
    );
  }
}