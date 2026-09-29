import 'package:flutter/material.dart';

import '../../shared/widgets/mobile_handover.dart';
import '../shell/mobile_role_shell.dart';
import 'mobile_login_page.dart';

const Duration _duration = Duration(milliseconds: 1000);

// Both pages stay on screen, untouchable, while the card becomes the menu bar and back.
class MobileSignInHandover extends StatefulWidget
{
  final bool signedIn;

  const MobileSignInHandover({super.key, required this.signedIn});

  @override
  State<MobileSignInHandover> createState() => _MobileSignInHandoverState();
}

class _MobileSignInHandoverState extends State<MobileSignInHandover> with SingleTickerProviderStateMixin
{
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.signedIn ? 1 : 0,
  )..addStatusListener(_onStatus);

  final GlobalKey _cardKey = GlobalKey();

  @override
  void didUpdateWidget(MobileSignInHandover oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.signedIn != oldWidget.signedIn)
    {
      widget.signedIn ? _progress.forward() : _progress.reverse();
    }
  }

  @override
  void dispose()
  {
    _progress.dispose();
    super.dispose();
  }

  // Rebuilds at the end to drop the old page; didUpdateWidget covers the start.
  void _onStatus(AnimationStatus status)
  {
    if (!status.isAnimating)
    {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final AnimationStatus status = _progress.status;
    final bool moving = status.isAnimating;

    return MobileHandover(
      progress: _progress,
      cardKey: _cardKey,
      moving: moving,
      child: IgnorePointer(
        ignoring: moving,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (status != AnimationStatus.dismissed)
              const KeyedSubtree(key: ValueKey('area'), child: MobileRoleShell()),
            if (status != AnimationStatus.completed)
              const KeyedSubtree(key: ValueKey('signIn'), child: MobileLoginPage()),
          ],
        ),
      ),
    );
  }
}
