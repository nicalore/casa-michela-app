import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/language/app_language.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import 'app_empty_card.dart';
import 'app_gradient_button.dart';

// A retry failing at once would only flash its spinner.
const Duration kRetryShortestBusy = Duration(milliseconds: 600);

/// What a failed load says: the server out of reach, or the page's own sentence.
class LoadFailureText
{
  final IconData icon;
  final String message;
  final String? detail;

  const LoadFailureText._(this.icon, this.message, this.detail);

  factory LoadFailureText.of(Object? error, String message)
  {
    if (error != null && isConnectionFailure(error))
    {
      return LoadFailureText._(Icons.wifi_off_rounded, kUnreachableTitle, kUnreachableDetail);
    }

    return LoadFailureText._(Icons.error_outline_rounded, message, null);
  }
}

/// Keeps the button busy while [onRetry] runs; the page swaps the card away once it loads.
mixin RetryRunner<T extends StatefulWidget> on State<T>
{
  bool retrying = false;

  Future<void> Function() get retry;

  Future<void> runRetry() async
  {
    if (retrying)
    {
      return;
    }

    setState(() => retrying = true);

    final Stopwatch watch = Stopwatch()..start();

    try
    {
      await retry();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'un nuovo tentativo di caricamento');
    }

    final Duration left = kRetryShortestBusy - watch.elapsed;

    if (mounted && left > Duration.zero)
    {
      await Future<void>.delayed(left);
    }

    if (mounted)
    {
      setState(() => retrying = false);
    }
  }
}

/// The same failure in one sentence, for a snackbar.
String loadFailureSentence(Object? error, String message)
{
  return error != null && isConnectionFailure(error) ? connectionFailureMessage : message;
}

/// A failed load inside a dialog or a card: no card of its own, the button under the text.
class AppLoadFailedPanel extends StatefulWidget
{
  final Object? error;

  // Shown when the server answered with a refusal.
  final String message;

  final Future<void> Function() onRetry;

  const AppLoadFailedPanel({super.key, required this.error, required this.message, required this.onRetry});

  @override
  State<AppLoadFailedPanel> createState() => _AppLoadFailedPanelState();
}

class _AppLoadFailedPanelState extends State<AppLoadFailedPanel> with RetryRunner
{
  @override
  Future<void> Function() get retry => widget.onRetry;

  @override
  Widget build(BuildContext context)
  {
    final LoadFailureText text = LoadFailureText.of(widget.error, widget.message);
    final String? detail = text.detail;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(text.icon, size: 30, color: AppTheme.trialTealDeepText),
          const SizedBox(height: 10),
          Text(
            emptyCardText(text.message),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.trialTealDeepText,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: AppTheme.trialMutedText,
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppGradientButton(
            label: tr('RIPROVA', 'TRY AGAIN'),
            icon: Icons.refresh_rounded,
            busy: retrying,
            height: 44,
            fontSize: 14,
            horizontalPadding: 22,
            onPressed: runRetry,
          ),
        ],
      ),
    );
  }
}

/// A failed load centred in the room left, with the button that reads it again.
class AppLoadFailedRoom extends StatefulWidget
{
  final Object? error;

  // Shown when the server answered with a refusal.
  final String message;

  final Future<void> Function() onRetry;

  const AppLoadFailedRoom({super.key, required this.error, required this.message, required this.onRetry});

  @override
  State<AppLoadFailedRoom> createState() => _AppLoadFailedRoomState();
}

class _AppLoadFailedRoomState extends State<AppLoadFailedRoom> with RetryRunner
{
  @override
  Future<void> Function() get retry => widget.onRetry;

  @override
  Widget build(BuildContext context)
  {
    final LoadFailureText text = LoadFailureText.of(widget.error, widget.message);

    return AppEmptyRoom(
      card: AppEmptyCard(icon: text.icon, message: text.message, detail: text.detail),
      below: [
        AppGradientButton(
          label: tr('RIPROVA', 'TRY AGAIN'),
          icon: Icons.refresh_rounded,
          busy: retrying,
          onPressed: runRetry,
        ),
      ],
    );
  }
}
