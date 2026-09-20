import 'package:flutter/material.dart';

const Duration _transition = Duration(milliseconds: 300);

class AppSlideSwitcher extends StatelessWidget
{
  final int index;
  final bool movingForward;

  final Widget child;

  const AppSlideSwitcher({
    super.key,
    required this.index,
    required this.movingForward,
    required this.child,
  });

  @override
  Widget build(BuildContext context)
  {
    return AnimatedSwitcher(
      duration: _transition,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [
          for (final previous in previousChildren)
            Positioned(top: 0, left: 0, right: 0, child: previous),
          ?currentChild,
        ],
      ),
      transitionBuilder: (child, animation)
      {
        final isEntering = (child.key as ValueKey<int>).value == index;
        final beginOffset = movingForward
            ? (isEntering ? const Offset(0.05, 0) : const Offset(-0.05, 0))
            : (isEntering ? const Offset(-0.05, 0) : const Offset(0.05, 0));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(index), child: child),
    );
  }
}
