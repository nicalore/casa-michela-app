// ApiService wraps backend failures in a plain Exception, whose toString()
// prefixes the message with "Exception: ". That prefix must not reach the user.
String readableApiError(Object error) => error.toString().replaceAll('Exception: ', '');