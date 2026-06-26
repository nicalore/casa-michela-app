class CityDistributionItem 
{
  final String city;
  final int    count;

  CityDistributionItem({required this.city, required this.count});

  factory CityDistributionItem.fromJson(Map<String, dynamic> json) 
  {
    return CityDistributionItem(
      city:  json['city'],
      count: json['count'],
    );
  }
}