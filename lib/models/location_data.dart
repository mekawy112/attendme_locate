class LocationData {
  final int id;
  final String name;
  final String location;

  LocationData({
    required this.id,
    required this.name,
    required this.location,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      id: json['id'],
      name: json['name'],
      location: json['location'],
    );
  }
}
