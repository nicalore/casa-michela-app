import 'package:flutter/foundation.dart';

// ApiService wraps failures in Exception, whose toString() prefixes
// "Exception: "; that prefix must not reach the user.
String readableApiError(Object error) => error.toString().replaceAll('Exception: ', '');

// The full failure, console only: nothing is printed in release.
void reportCaughtError(Object error, StackTrace stackTrace, {required String during})
{
  if (!kDebugMode)
  {
    return;
  }

  debugPrint('Errore durante $during: $error');
  debugPrintStack(stackTrace: stackTrace);
}
