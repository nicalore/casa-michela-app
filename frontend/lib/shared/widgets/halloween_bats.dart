import 'package:flutter/material.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/utils/halloween.dart';
import '../../core/utils/rome_clock.dart';
import '../../features/auth/models/me_response.dart';
import 'bat_flight.dart';
import 'page_transition.dart';

const Color _far = Color(0xFF5D6676);
const Color _near = Color(0xFF15121C);

// One flight per launch, on the home only: a home bar no longer on show ends it.
class HalloweenBats extends StatefulWidget
{
  final MeResponse user;

  // Page coordinates; painted under the bar so the bats come out from beneath it.
  final Rect source;

  const HalloweenBats({super.key, required this.user, required this.source});

  // Tax code already greeted this launch.
  static String? _celebrated;

  static BatFlight? _flight;

  // Home bars currently painting; the flight ends when none is left.
  static final Set<_HalloweenBatsState> _hosts = {};

  static void _startFor(MeResponse user)
  {
    if (!VisualEffects.on || !isHalloweenFor(user.birthDate, romeNow()) || _celebrated == user.taxCode)
    {
      return;
    }

    _celebrated = user.taxCode;
    _flight = BatFlight(shouldEnd: () => _hosts.isEmpty);
  }

  @visibleForTesting
  static void debugReset()
  {
    _flight?.end();
    _flight = null;
    _celebrated = null;
  }

  @visibleForTesting
  static double? get debugElapsed => _flight == null || _flight!.done ? null : _flight!.elapsed;

  @override
  State<HalloweenBats> createState() => _HalloweenBatsState();
}

class _HalloweenBatsState extends State<HalloweenBats>
{
  bool _hosting = false;

  BatFlight? _flight;

  bool get _shown
  {
    return isDestinationShown(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    final bool shown = _shown;

    if (shown != _hosting)
    {
      _hosting = shown;

      if (shown)
      {
        HalloweenBats._hosts.add(this);
      }
      else
      {
        HalloweenBats._hosts.remove(this);
      }
    }

    if (shown)
    {
      HalloweenBats._startFor(widget.user);
    }

    _listen(HalloweenBats._flight);
  }

  @override
  void didUpdateWidget(HalloweenBats oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (_hosting && oldWidget.user.taxCode != widget.user.taxCode)
    {
      HalloweenBats._startFor(widget.user);
      _listen(HalloweenBats._flight);
    }
  }

  void _listen(BatFlight? flight)
  {
    if (identical(flight, _flight))
    {
      return;
    }

    _flight?.removeListener(_onFlight);
    _flight = flight;
    _flight?.addListener(_onFlight);
  }

  // Ticks repaint through the painter; only the end needs a rebuild, to drop it.
  void _onFlight()
  {
    if (_flight!.done)
    {
      setState(() {});
    }
  }

  @override
  void dispose()
  {
    HalloweenBats._hosts.remove(this);
    _flight?.removeListener(_onFlight);
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final BatFlight? flight = _flight;

    if (flight == null || flight.done)
    {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final List<FlyingBat> bats = flight.planFor(BatFlightSpec.desktop(constraints.biggest, widget.source));

        return IgnorePointer(
          child: RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: BatsPainter(flight: flight, bats: bats, far: _far, near: _near),
              ),
            ),
          ),
        );
      },
    );
  }
}
