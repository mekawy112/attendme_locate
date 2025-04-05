import 'dart:ui';
import 'dart:math' as math;

class Recognition {
  String name;
  String studentId;
  List<double>? embedding;
  double distance;
  
  /// Constructs a Recognition.
  Recognition(this.name, this.studentId, this.embedding, this.distance);
  
  /// Crea una copia con valores actualizados
  Recognition copyWith({
    String? name,
    String? studentId,
    List<double>? embedding,
    double? distance,
  }) {
    return Recognition(
      name ?? this.name,
      studentId ?? this.studentId,
      embedding ?? this.embedding,
      distance ?? this.distance,
    );
  }

  // Calculate similarity with another face embedding
  double calculateSimilarity(List<double> otherEmbedding) {
    if (embedding == null) return 0.0;
    if (embedding!.length != otherEmbedding.length) {
      throw Exception('Embedding dimensions do not match');
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding!.length; i++) {
      dotProduct += embedding![i] * otherEmbedding[i];
      norm1 += embedding![i] * embedding![i];
      norm2 += otherEmbedding[i] * otherEmbedding[i];
    }

    norm1 = math.sqrt(norm1);
    norm2 = math.sqrt(norm2);

    if (norm1 == 0 || norm2 == 0) return 0.0;

    return (dotProduct / (norm1 * norm2)).clamp(0.0, 1.0);
  }
}
