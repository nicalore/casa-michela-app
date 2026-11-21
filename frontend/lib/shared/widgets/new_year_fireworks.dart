import 'package:flutter/material.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/utils/festivities.dart';
import '../../core/utils/rome_clock.dart';
import '../../features/auth/models/me_response.dart';
import 'fireworks_show.dart';
import 'page_transition.dart';

// One show per launch, on the home only: a home bar no longer on show ends it.
class NewYearFireworks extends StatefulWidget
{
  final MeResponse user;

  // The bar in page coordinates; the rockets burst below it.
  final Rect source;

  const NewYearFireworks({super.key, required this.user, required this.source});

  // Tax code already greeted this launch.
  static String? _celebrated;

  static FireworksShow? _show;

  // Home bars currently painting; the show ends when none is left.
  static final Set<_NewYearFireworksState> _hosts = {};

  static void _startFor(MeResponse user)
  {
    if (!VisualEffects.on || festivityFor(user.birthDate, romeNow()) != Festivity.newYear || _celebrated == user.taxCode)
    {
      return;
    }

    _celebrated = user.taxCode;
    _show = FireworksShow(shouldEnd: () => _hosts.isEmpty);
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
  State<NewYearFireworks> createState() => _NewYearFireworksState();
}

class _NewYearFireworksState extends State<NewYearFireworks>
{
  bool _hosting = false;

  FireworksShow? _show;

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
        NewYearFireworks._hosts.add(this);
      }
      else
      {
        NewYearFireworks._hosts.remove(this);
      }
    }

    if (shown)
    {
      NewYearFireworks._startFor(widget.user);
    }

    _listen(NewYearFireworks._show);
  }

  @override
  void didUpdateWidget(NewYearFireworks oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (_hosting && oldWidget.user.taxCode != widget.user.taxCode)
    {
      NewYearFireworks._startFor(widget.user);
      _listen(NewYearFireworks._show);
    }
  }

  void _listen(FireworksShow? show)
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
    NewYearFireworks._hosts.remove(this);
    _show?.removeListener(_onShow);
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final FireworksShow? show = _show;

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
                painter: FireworksPainter(show: show, spec: FireworksSpec.desktop(constraints.biggest, widget.source)),
              ),
            ),
          ),
        );
      },
    );
  }
}
