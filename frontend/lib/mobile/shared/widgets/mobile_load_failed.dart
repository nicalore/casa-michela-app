import 'package:flutter/material.dart';

import '../../../shared/widgets/app_load_failed.dart';
import 'mobile_empty_card.dart';
import 'mobile_gold_button.dart';

/// A failed load: the empty card saying why, the gold button under it reading it again.
class MobileLoadFailed extends StatefulWidget
{
  final Object? error;

  // Shown when the server answered with a refusal.
  final String message;

  final Future<void> Function() onRetry;

  final bool tablet;

  const MobileLoadFailed({
    super.key,
    required this.error,
    required this.message,
    required this.onRetry,
    required this.tablet,
  });

  @override
  State<MobileLoadFailed> createState() => _MobileLoadFailedState();
}

class _MobileLoadFailedState extends State<MobileLoadFailed> with RetryRunner
{
  @override
  Future<void> Function() get retry => widget.onRetry;

  @override
  Widget build(BuildContext context)
  {
    final LoadFailureText text = LoadFailureText.of(widget.error, widget.message);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileEmptyCard(icon: text.icon, message: text.message, detail: text.detail, tablet: widget.tablet),
        const SizedBox(height: 20),
        MobileGoldButton(
          label: 'Riprova',
          icon: Icons.refresh_rounded,
          busy: retrying,
          onPressed: runRetry,
        ),
      ],
    );
  }
}
