import 'package:flutter/material.dart';

import '../../../core/utils/birthday.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_state.dart';
import '../../../shared/widgets/confetti_shower.dart';

// A band above the screen, so pieces fall in rather than appear.
const double _sourceHeight = 60;

// Lives in the shell above the pages, so navigating rebuilds it without a fresh shower.
class MobileBirthdayConfetti extends StatefulWidget
{
  const MobileBirthdayConfetti({super.key});

  // Tax code already celebrated this launch.
  static String? _celebrated;

  @visibleForTesting
  static void debugReset() => _celebrated = null;

  @override
  State<MobileBirthdayConfetti> createState() => _MobileBirthdayConfettiState();
}

class _MobileBirthdayConfettiState extends State<MobileBirthdayConfetti>
{
  final ApiService _apiService = ApiService();

  ConfettiShower? _shower;

  @override
  void initState()
  {
    super.initState();

    _apiService.identity.addListener(_onIdentity);
    _apiService.authState.addListener(_onIdentity);
    _start(notify: false);
  }

  @override
  void dispose()
  {
    _apiService.identity.removeListener(_onIdentity);
    _apiService.authState.removeListener(_onIdentity);
    _shower?.removeListener(_onShower);
    _shower?.end();

    super.dispose();
  }

  void _onIdentity() => _start(notify: true);

  void _start({required bool notify})
  {
    final MeResponse? user = _apiService.identity.value;

    if (_apiService.authState.value != AuthState.authenticated ||
        user == null ||
        !isBirthdayToday(user.birthDate, DateTime.now()) ||
        MobileBirthdayConfetti._celebrated == user.taxCode)
    {
      return;
    }

    MobileBirthdayConfetti._celebrated = user.taxCode;

    _shower?.removeListener(_onShower);
    _shower?.end();
    _shower = ConfettiShower()..addListener(_onShower);

    if (notify)
    {
      setState(() {});
    }
  }

  // Ticks repaint through the painter; only the end needs a rebuild, to drop it.
  void _onShower()
  {
    if (_shower!.done && mounted)
    {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final ConfettiShower? shower = _shower;

    if (shower == null || shower.done)
    {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints)
          {
            final Rect source = Rect.fromLTWH(0, -_sourceHeight, constraints.maxWidth, _sourceHeight);

            shower.noteDrop(constraints.maxHeight - source.top);

            return SizedBox.expand(
              child: CustomPaint(painter: ConfettiPainter(shower: shower, source: source)),
            );
          },
        ),
      ),
    );
  }
}
