import 'dart:ui';

class Recognition {
  String name;
  Rect location;
  List<double>? embedding; 
  double distance;
  
  /// Constructs a Recognition.
  Recognition(this.name, this.location, this.embedding, this.distance);
  
  /// Crea una copia con valores actualizados
  Recognition copyWith({String? name, Rect? location, List<double>? embedding, double? distance}) {
    return Recognition(
      name ?? this.name,
      location ?? this.location,
      embedding ?? this.embedding,
      distance ?? this.distance,
    );
  }
}
