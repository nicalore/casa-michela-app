// What the device answers about showing notifications; denied can no longer be asked.
enum PushPermission
{
  unsupported,
  prompt,
  granted,
  denied,
}

enum PushNewsType
{
  arrived,
  opened,
  // Read or withdrawn elsewhere: the list may have changed.
  dismissed,
  // The device's push address changed: the server must be told the new one.
  renewed,
}

class PushNews
{
  final PushNewsType type;
  final int id;

  // Arrived with no banner from the system: the app has to show it itself.
  final bool quiet;

  const PushNews(this.type, this.id, {this.quiet = false});
}
