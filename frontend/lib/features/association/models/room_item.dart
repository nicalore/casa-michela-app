class RoomItem
{
  final int id;
  final String name;
  final String? description;

  // Null when uncounted; null is not zero.
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
