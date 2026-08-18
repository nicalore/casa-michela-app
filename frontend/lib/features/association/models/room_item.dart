// A place in the building, assigned to a teacher for a day.
class RoomItem
{
  final int id;
  final String name;
  final String? description;

  // Null wherever nobody has counted, and null is not zero: an unmeasured room
  // holds as many as it holds, so whoever shows one says nothing about it
  // rather than writing a number that was never checked.
  final int? capacity;

  final DateTime createdAt;

  const RoomItem({
    required this.id,
    required this.name,
    this.description,
    this.capacity,
    required this.createdAt,
  });

  factory RoomItem.fromJson(Map<String, dynamic> json)
  {
    return RoomItem(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      capacity: json['capacity'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
