import 'package:flutter/foundation.dart';

// ApiService wraps backend failures in a plain Exception, whose toString()
// prefixes the message with "Exception: ". That prefix must not reach the user.
String readableApiError(Object error) => error.toString().replaceAll('Exception: ', '');

// The whole failure on the console, and only while developing.
//
// On screen a failed load says one sentence and always the same one, because
// whoever reads it can do nothing with it. That sentence is also all that is
// left to whoever has to find the fault, and it fits a dead server as well as a
// misread field at the bottom of a nested list. The real cause, with its stack,
// goes through here, where only a developer sees it: nothing is printed in
// release.
void reportCaughtError(Object error, StackTrace stackTrace, {required String during})
{
  if (!kDebugMode)
  {
    return;
  }

  debugPrint('Errore durante $during: $error');
  debugPrintStack(stackTrace: stackTrace);
}
