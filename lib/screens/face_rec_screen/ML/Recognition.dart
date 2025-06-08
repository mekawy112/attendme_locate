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
    if (embedding == null || embedding!.isEmpty) {
      print('Warning: Embedding is null or empty');
      return 0.0;
    }
    
    if (otherEmbedding.isEmpty) {
      print('Warning: Other embedding is empty');
      return 0.0;
    }
    
    try {
      // If dimensions don't match, we'll try to use the common dimensions
      int minLength = math.min(embedding!.length, otherEmbedding.length);
      if (minLength == 0) {
        print('Error: One of the embeddings has zero length');
        return 0.0;
      }
      
      if (embedding!.length != otherEmbedding.length) {
        print('Warning: Embedding dimensions do not match (${embedding!.length} vs ${otherEmbedding.length})');
        print('Using only the first $minLength dimensions');
      }

      // Calculate multiple similarity metrics for better accuracy
      
      // 1. Cosine similarity (main metric)
      double dotProduct = 0.0;
      double norm1 = 0.0;
      double norm2 = 0.0;

      for (int i = 0; i < minLength; i++) {
        // Add checks to avoid NaN values
        double val1 = embedding![i].isFinite ? embedding![i] : 0.0;
        double val2 = otherEmbedding[i].isFinite ? otherEmbedding[i] : 0.0;
        
        dotProduct += val1 * val2;
        norm1 += val1 * val1;
        norm2 += val2 * val2;
      }

      norm1 = math.sqrt(norm1);
      norm2 = math.sqrt(norm2);

      if (norm1 < 1e-10 || norm2 < 1e-10) {
        print('Warning: Near-zero norm detected (${norm1.toStringAsFixed(10)}, ${norm2.toStringAsFixed(10)})');
        return 0.0;
      }

      double cosineSimilarity = (dotProduct / (norm1 * norm2));
      
      // 2. Euclidean distance (L2) as secondary metric
      double l2Distance = 0.0;
      for (int i = 0; i < minLength; i++) {
        double diff = (embedding![i] - otherEmbedding[i]);
        l2Distance += diff * diff;
      }
      l2Distance = math.sqrt(l2Distance);
      
      // Convert L2 distance to similarity measure (1 for identical, 0 for very different)
      double l2Similarity = 1.0 / (1.0 + l2Distance);
      
      // 3. Combine similarity metrics (weighted average)
      // Give more weight to cosine similarity as it's often more reliable for face embeddings
      double combinedSimilarity = (cosineSimilarity * 0.7) + (l2Similarity * 0.3);
      
      // 4. Apply a non-linear transformation to boost values in the middle range
      // This helps with recognition by making the similarity distribution more usable
      double boostedSimilarity = math.pow(combinedSimilarity, 0.85).toDouble();
      
      // Check for invalid values (can happen due to floating point errors)
      if (!boostedSimilarity.isFinite) {
        print('Warning: Got non-finite similarity value after boosting: $boostedSimilarity');
        return 0.0;
      }
      
      // Ensure the value is within valid range
      return boostedSimilarity.clamp(0.0, 1.0);
    } catch (e) {
      print('Error calculating similarity: $e');
      return 0.0;
    }
  }
}
