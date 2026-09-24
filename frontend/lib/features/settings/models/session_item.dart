enum SessionDeviceType
{
  desktop,
  phone,
  tablet,
  unknown;

  static SessionDeviceType fromCode(String? code)
  {
    return switch (code)
    {
      'DESKTOP' => SessionDeviceType.desktop,
      'PHONE' => SessionDeviceType.phone,
      'TABLET' => SessionDeviceType.tablet,
      _ => SessionDeviceType.unknown,
    };
  }
}

class SessionItem
{
  final String sessionId;

  // Both already converted to the local clock.
  final DateTime loggedInAt;
  final DateTime lastUsedAt;

  final SessionDeviceType deviceType;

  // "Chrome su macOS", "App iOS"; null when the server could not tell.
  final String? deviceName;

  // The session this very client is using.
  final bool isCurrent;

  const SessionItem({
    required this.sessionId,
    required this.loggedInAt,
    required this.lastUsedAt,
    required this.deviceType,
    required this.deviceName,
    required this.isCurrent,
  });

  factory SessionItem.fromJson(Map<String, dynamic> json)
  {
    return SessionItem(
      sessionId: json['session_id'],
      loggedInAt: DateTime.parse(json['logged_in_at']).toLocal(),
      lastUsedAt: DateTime.parse(json['last_used_at']).toLocal(),
      deviceType: SessionDeviceType.fromCode(json['device_type']),
      deviceName: json['device_name'],
      isCurrent: json['current'] == true,
    );
  }
}
