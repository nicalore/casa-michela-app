// Parsing helpers shared by the model layer. They exist to keep the JSON quirks
// of the backend in one place rather than repeated in every fromJson.

/// Parses a display-only date. The resulting DateTime keeps whatever zone
/// [DateTime.parse] infers, which is harmless for values that are only shown.
DateTime? parseDate(Object? value)
{
  return value == null ? null : DateTime.parse(value as String);
}

/// Parses a value whose absolute instant matters, such as an optimistic
/// concurrency token sent back to the server.
///
/// [DateTime.parse] returns a local-time value for numeric offsets like
/// `+00:00`, and `toIso8601String()` then emits no offset at all, so the server
/// would compare a shifted timestamp. Forcing UTC makes the round trip
/// lossless, and is a no-op when the payload already ends with `Z`.
DateTime? parseInstant(Object? value)
{
  return value == null ? null : DateTime.parse(value as String).toUtc();
}

/// Parses an optional list of objects, keeping null distinct from empty: null
/// means the endpoint did not include the section at all, so callers can tell
/// "not loaded" from "loaded and empty".
List<T>? parseOptionalList<T>(Object? value, T Function(Map<String, dynamic>) fromJson)
{
  if (value == null)
  {
    return null;
  }

  return parseList(value, fromJson);
}

/// Parses a list of objects that the contract guarantees to be present. An
/// absent key is a contract violation, so the cast is left to throw.
List<T> parseList<T>(Object? value, T Function(Map<String, dynamic>) fromJson)
{
  return (value as List<dynamic>)
      .map((element) => fromJson(element as Map<String, dynamic>))
      .toList();
}

/// Parses a list of strings, treating an absent list as empty.
List<String> parseStringList(Object? value)
{
  return (value as List<dynamic>?)?.map((element) => element.toString()).toList() ?? [];
}

/// Normalises a JSON number to double. A whole value arrives as int, and a
/// direct cast to double would throw.
double parseDouble(Object? value)
{
  return (value as num).toDouble();
}

double? parseOptionalDouble(Object? value)
{
  return value == null ? null : (value as num).toDouble();
}