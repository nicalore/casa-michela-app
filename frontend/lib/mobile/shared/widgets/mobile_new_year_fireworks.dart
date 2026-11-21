import 'package:flutter/material.dart';

import '../../../core/utils/festivities.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_state.dart';
import '../../../shared/widgets/fireworks_show.dart';

// Lives in the shell above the pages, once per launch while the home is on show.
class MobileNewYearFireworks extends StatefulWidget
{
  // Leaving the home ends the show.
  final bool onHome;

  const MobileNewYearFireworks({super.key, required this.onHome});

  // Tax code already greeted this launch.
  static String? _celebrated;

  @visibleForTesting
  static void debugReset() => _celebrated = null;

  @override
  State<MobileNewYearFireworks> createState() => _MobileNewYearFireworksState();
}

class _MobileNewYearFireworksState extends State<MobileNewYearFireworks>
{
  final ApiService _apiService = ApiService();

  FireworksShow? _show;

  @override
  void initState()
  {
    super.initState();

    _apiService.identity.addListener(_onIdentity);
    _apiService.authState.addListener(_onIdentity);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    _start(notify: false);
  }

  @override
  void didUpdateWidget(MobileNewYearFireworks oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!widget.onHome)
    {
      _show?.end();
    }
    else if (!oldWidget.onHome)
    {
      _start(notify: false);
    }
  }

  @override
  void dispose()
  {
    _apiService.identity.removeListener(_onIdentity);
    _apiService.authState.removeListener(_onIdentity);
    _show?.removeListener(_onShow);
    _show?.end();

    super.dispose();
  }

  void _onIdentity() => _start(notify: true);

  void _start({required bool notify})
  {
    final MeResponse? user = _apiService.identity.value;

    if (!widget.onHome ||
        MediaQuery.disableAnimationsOf(context) ||
        _apiService.authState.value != AuthState.authenticated ||
        user == null ||
        festivityFor(user.birthDate, romeNow()) != Festivity.newYear ||
        MobileNewYearFireworks._celebrated == user.taxCode)
    {
      return;
    }

    MobileNewYearFireworks._celebrated = user.taxCode;

    _show?.removeListener(_onShow);
    _show?.end();
    _show = FireworksShow()..addListener(_onShow);

    if (notify)
    {
      setState(() {});
    }
  }

  // Ticks repaint through the painter; only the end needs a rebuild, to drop it.
  void _onShow()
  {
    if (_show!.done && mounted)
    {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final FireworksShow? show = _show;

    if (show == null || show.done)
    {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints)
          {
            return SizedBox.expand(
              child: CustomPaint(painter: FireworksPainter(show: show, spec: FireworksSpec.mobile(constraints.biggest))),
            );
          },
        ),
      ),
    );
  }
}
