import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const String kUnreachableTitle = 'Impossibile raggiungere il server';
const String kUnreachableDetail = 'Controlla la connessione e riprova.';

const String connectionFailureMessage = '$kUnreachableTitle. $kUnreachableDetail';

// Thrown by ApiService in place of its refusal text when no answer came back.
class ServerUnreachable implements Exception
{
  const ServerUnreachable();

  @override
  String toString() => connectionFailureMessage;
}

// No answer at all: offline, wrong host, timeout. A refusal has a response.
bool isConnectionFailure(Object error)
{
  return error is ServerUnreachable || (error is DioException && error.response == null);
}

// Strips the "Exception: " prefix of ApiService's wrapping; unwrapped Dio failures get one sentence.
String readableApiError(Object error)
{
  if (error is DioException || error is ServerUnreachable)
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
