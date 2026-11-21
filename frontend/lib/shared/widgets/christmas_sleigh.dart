import 'package:flutter/material.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/utils/festivities.dart';
import '../../core/utils/rome_clock.dart';
import '../../features/auth/models/me_response.dart';
import 'sleigh_flight.dart';
import 'page_transition.dart';

// Santa's sleigh once per launch on Christmas, on the home only: a home bar no longer on show ends it.
class ChristmasSleigh extends StatefulWidget
{
  final MeResponse user;

  // The bar in page coordinates; the sleigh flies below it.
  final Rect source;

  const ChristmasSleigh({super.key, required this.user, required this.source});

  // Tax code already greeted this launch.
  static String? _celebrated;

  static SleighFlight? _show;

  // Home bars currently painting; the show ends when none is left.
  static final Set<_ChristmasSleighState> _hosts = {};

  static void _startFor(MeResponse user)
  {
    if (!VisualEffects.on || festivityFor(user.birthDate, romeNow()) != Festivity.christmas || _celebrated == user.taxCode)
    {
      return;
    }

    _celebrated = user.taxCode;
    _show = SleighFlight(shouldEnd: () => _hosts.isEmpty);
  }

  @visibleForTesting
  static void debugReset()
  {
    _show?.end();
    _show = null;
    _celebrated = null;
  }

  @visibleForTesting
  static double? get debugElapsed => _show == null || _show!.done ? null : _show!.elapsed;

  @override
  State<ChristmasSleigh> createState() => _ChristmasSleighState();
}

class _ChristmasSleighState extends State<ChristmasSleigh>
{
  bool _hosting = false;

  SleighFlight? _show;

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
        ChristmasSleigh._hosts.add(this);
      }
      else
      {
        ChristmasSleigh._hosts.remove(this);
      }
    }

    if (shown)
    {
      ChristmasSleigh._startFor(widget.user);
    }

    _listen(ChristmasSleigh._show);
  }

  @override
  void didUpdateWidget(ChristmasSleigh oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (_hosting && oldWidget.user.taxCode != widget.user.taxCode)
    {
      ChristmasSleigh._startFor(widget.user);
      _listen(ChristmasSleigh._show);
    }
  }

  void _listen(SleighFlight? show)
  {
    if (identical(show, _show))
    {
      return;
    }

    _show?.removeListener(_onShow);
    _show = show;
    _show?.addListener(_onShow);
  }

  // Ticks repaint through the painter; only the end needs a rebuild, to drop it.
  void _onShow()
  {
    if (_show!.done)
    {
      setState(() {});
    }
  }

  @override
  void dispose()
  {
    ChristmasSleigh._hosts.remove(this);
    _show?.removeListener(_onShow);
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final SleighFlight? show = _show;

    if (show == null || show.done)
    {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        return IgnorePointer(
          child: RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: SleighPainter(flight: show, spec: SleighSpec.desktop(constraints.biggest, widget.source)),
              ),
            ),
          ),
        );
      },
    );
  }
}
