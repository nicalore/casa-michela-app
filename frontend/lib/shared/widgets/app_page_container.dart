import 'package:flutter/material.dart';

class AppPageContainer extends StatefulWidget
{
  final Widget Function(
    BuildContext context,
    double width,
    double height,
  ) builder;

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

  @override
  void dispose()
  {
    //Release resources
    _verticalController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        //Calculate dimensions
        final width = constraints.maxWidth < widget.minWidth
            ? widget.minWidth
            : constraints.maxWidth;

        final height = constraints.maxHeight < widget.minHeight
            ? widget.minHeight
            : constraints.maxHeight;

        return Scrollbar(
          controller: _verticalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalController,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: width,
                minHeight: height,
              ),
              child: widget.builder(
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