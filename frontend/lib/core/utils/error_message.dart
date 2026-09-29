import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const String connectionFailureMessage = 'Impossibile raggiungere il server. Controlla la connessione e riprova.';

// No answer at all: offline, wrong host, timeout. A refusal has a response.
bool isConnectionFailure(Object error) => error is DioException && error.response == null;

// Strips the "Exception: " prefix of ApiService's wrapping; unwrapped Dio failures get one sentence.
String readableApiError(Object error)
{
  if (error is DioException)
  {
    return connectionFailureMessage;
  }

  return error.toString().replaceAll('Exception: ', '');
}

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
