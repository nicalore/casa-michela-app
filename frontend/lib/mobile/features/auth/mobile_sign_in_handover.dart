import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/widgets/mobile_handover.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../shell/mobile_role_shell.dart';
import 'mobile_login_page.dart';

const Duration _duration = Duration(milliseconds: 1000);

// Past this the area comes in with its wheel rather than keep the button spinning.
const Duration _holdCap = Duration(seconds: 3);

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

  final ValueNotifier<int> _holds = ValueNotifier<int>(0);

  bool _waiting = false;
  Timer? _cap;

  @override
  void didUpdateWidget(MobileSignInHandover oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.signedIn == oldWidget.signedIn)
    {
      return;
    }

    if (widget.signedIn)
    {
      _waiting = true;
      // After the area's first build, when its pages have asked to be waited for.
      WidgetsBinding.instance.addPostFrameCallback((_) => _startWhenLoaded());
    }
    else
    {
      _stopWaiting();
      _progress.reverse();
    }
  }

  @override
  void dispose()
  {
    _stopWaiting();
    _holds.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _startWhenLoaded()
  {
    if (!mounted || !_waiting)
    {
      return;
    }

    if (_holds.value == 0)
    {
      _start();

      return;
    }

    _holds.addListener(_onHolds);
    _cap = Timer(_holdCap, _start);
  }

  void _onHolds()
  {
    if (_holds.value == 0)
    {
      _start();
    }
  }

  void _stopWaiting()
  {
    _waiting = false;
    _holds.removeListener(_onHolds);
    _cap?.cancel();
    _cap = null;
  }

  void _start()
  {
    if (!mounted || !_waiting)
    {
      return;
    }

    setState(_stopWaiting);
    _progress.forward();
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
      waiting: _waiting,
      child: MobileHoldScope(
        holds: _holds,
        waiting: _waiting,
        child: IgnorePointer(
          ignoring: moving || _waiting,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_waiting || status != AnimationStatus.dismissed)
                const KeyedSubtree(key: ValueKey('area'), child: MobileRoleShell()),
              if (status != AnimationStatus.completed)
                const KeyedSubtree(key: ValueKey('signIn'), child: MobileLoginPage()),
            ],
          ),
        ),
      ),
    );
  }
}
