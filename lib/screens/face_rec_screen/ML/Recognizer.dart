import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'dart:convert'; // Add this import for jsonDecode
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../DB/DatabaseHelper.dart';
import 'Recognition.dart';

class Recognizer {
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;
  static const int WIDTH = 112;
  static const int HEIGHT = 112;
  DatabaseHelper? dbHelper;
  List<Recognition> registered = [];
  String get modelName => 'assets/mobile_face_net.tflite';
  bool _modelLoaded = false;

  Recognizer({int? numThreads}) {
    _interpreterOptions = InterpreterOptions();

    if (numThreads != null) {
      _interpreterOptions.threads = numThreads;
    }

    // Initialize the model asynchronously
    _initializeAsync(numThreads);
  }

  Future<void> _initializeAsync(int? numThreads) async {
    await loadModel();
    await initDB();
    _modelLoaded = true;
  }

  Future<void> initDB() async {
    dbHelper = DatabaseHelper();
    await dbHelper!.init();
    await loadRegisteredFaces();
    print("Database initialized with ${registered.length} registered faces");
  }

  // u062au062du0645u064au0644 u0627u0644u0648u062cu0648u0647 u0627u0644u0645u0633u062cu0644u0629 u0645u0646 u0642u0627u0639u062fu0629 u0627u0644u0628u064au0627u0646u0627u062a
  Future<void> loadRegisteredFaces() async {
    if (dbHelper == null) {
      dbHelper = DatabaseHelper();
      await dbHelper!.init();
    }
    await _loadRegisteredFacesFromDB();
  }

  // u062au062du0645u064au0644 u0648u062cu0647 u0645u062du062fu062f u0628u0646u0627u0621u064b u0639u0644u0649 u0645u0639u0631u0641 u0627u0644u0637u0627u0644u0628
  Future<Recognition?> loadFaceByStudentId(String studentId) async {
    if (dbHelper == null) {
      dbHelper = DatabaseHelper();
      await dbHelper!.init();
    }

    try {
      final result = await dbHelper!.query(
        DatabaseHelper.table,
        where: '${DatabaseHelper.columnStudentId} = ?',
        whereArgs: [studentId],
      );

      if (result.isEmpty) {
        print("No face found for student ID: $studentId");
        return null;
      }

      final row = result.first;
      String name = row[DatabaseHelper.columnName];

      // Handle embedding string format safely
      String embeddingStr =
          row[DatabaseHelper.columnEmbedding] ?? ''; // Ensure not null
      List<double> embd = [];

      // Check embedding format and parse it safely
      try {
        // Trim whitespace first
        String trimmedStr = embeddingStr.trim();

        if (trimmedStr.startsWith('[') && trimmedStr.endsWith(']')) {
          // Try direct JSON decoding
          List<dynamic> jsonList = jsonDecode(trimmedStr);
          embd =
              jsonList.map((e) {
                if (e is num) {
                  return e.toDouble();
                } else if (e is String) {
                  return double.tryParse(e) ??
                      0.0; // Handle strings within JSON array
                }
                return 0.0; // Default for unexpected types
              }).toList();
        } else if (trimmedStr.contains(',')) {
          // Fallback to comma-separated format
          embd =
              trimmedStr
                  .split(',')
                  .map(
                    (e) => double.tryParse(e.trim()) ?? 0.0,
                  ) // Use tryParse for safety
                  .toList();
        } else {
          print(
            "Unknown or invalid embedding format for student ID $studentId",
          );
          return null;
        }
      } catch (e, stacktrace) {
        // Catch potential errors during parsing
        print("Error parsing embedding for student ID $studentId: $e");
        print("Stacktrace: $stacktrace");
        print("Raw embedding string: $embeddingStr"); // Log the full string
        return null;
      }

      // Validate the embedding
      bool hasInvalidValues = false;
      for (double value in embd) {
        if (!value.isFinite) {
          hasInvalidValues = true;
          break;
        }
      }

      if (hasInvalidValues || embd.isEmpty) {
        print(
          "Invalid or empty embedding data for student ID: $studentId after parsing",
        );
        return null;
      }

      // Normalize the embedding to ensure it's usable for comparison
      _normalizeEmbedding(embd);

      print(
        "Loaded face for student ID: $studentId, Name: $name, Embedding length: ${embd.length}",
      );

      return Recognition(name, studentId, embd, 0.0);
    } catch (e) {
      print("Error loading face by student ID: $e");
      return null;
    }
  }

  // u062au062du0645u064au0644 u062cu0645u064au0639 u0627u0644u0648u062cu0648u0647 u0627u0644u0645u0633u062cu0644u0629 u0645u0646 u0642u0627u0639u062fu0629 u0627u0644u0628u064au0627u0646u0627u062a
  Future<void> _loadRegisteredFacesFromDB() async {
    registered.clear();
    final allRows = await dbHelper!.queryAllRows();
    print("Loading registered faces: ${allRows.length} records found");

    for (final row in allRows) {
      try {
        String name = row[DatabaseHelper.columnName] ?? 'Unknown';
        String studentId = row[DatabaseHelper.columnStudentId] ?? "unknown";
        String embeddingStr = row[DatabaseHelper.columnEmbedding] ?? '';
        List<double> embd = [];

        if (embeddingStr.isEmpty) {
          print(
            "Skipping face for $name ($studentId) due to empty embedding string.",
          );
          continue;
        }

        // Robust parsing logic copied from loadFaceByStudentId
        try {
          String trimmedStr = embeddingStr.trim();
          if (trimmedStr.startsWith('[') && trimmedStr.endsWith(']')) {
            List<dynamic> jsonList = jsonDecode(trimmedStr);
            embd =
                jsonList.map((e) {
                  if (e is num) {
                    return e.toDouble();
                  } else if (e is String) {
                    return double.tryParse(e) ?? 0.0;
                  }
                  return 0.0;
                }).toList();
          } else if (trimmedStr.contains(',')) {
            embd =
                trimmedStr
                    .split(',')
                    .map((e) => double.tryParse(e.trim()) ?? 0.0)
                    .toList();
          } else {
            print(
              "Skipping face for $name ($studentId) due to unknown embedding format.",
            );
            continue; // Skip this record
          }
        } catch (e, stacktrace) {
          print("Error parsing embedding for $name ($studentId): $e");
          print("Stacktrace: $stacktrace");
          print("Raw embedding string: $embeddingStr");
          continue; // Skip this record
        }

        // Validate embedding
        bool hasInvalidValues = false;
        for (double value in embd) {
          if (!value.isFinite) {
            hasInvalidValues = true;
            break;
          }
        }

        if (hasInvalidValues || embd.isEmpty) {
          print(
            "Skipping face for $name ($studentId) due to invalid or empty embedding data after parsing.",
          );
          continue; // Skip this record
        }

        _normalizeEmbedding(embd);
        Recognition recognition = Recognition(name, studentId, embd, 0);
        registered.add(recognition);
        print(
          "Registered face: $name (Student ID: $studentId) with ${embd.length} embedding points",
        );
      } catch (e) {
        print("Error processing face record: $e for row: $row");
      }
    }
    print(
      "Finished loading. Total valid registered faces: ${registered.length}",
    );
  }

  // u0639u0645u0644u064au0629 u0627u0644u062au0639u0631u0641 u0639u0644u0649 u0627u0644u0648u062cu0648u0647 u0645u0639 u062au062du0633u064au0646u0627u062a u0644u0644u062au062du0642u0642 u0645u0646 u0645u0639u0631u0641 u0627u0644u0637u0627u0644u0628
  Recognition? recognizeFace(List<double> embedding, String? studentId) {
    if (studentId != null && registered.isNotEmpty) {
      for (Recognition face in registered) {
        if (face.studentId == studentId) {
          double similarity = calculateSimilarityScore(
            embedding,
            face.embedding!,
          );
          print(
            "Checking face for specific student ID: $studentId, Similarity: ${(similarity * 100).toStringAsFixed(1)}%",
          );

          if (similarity >= 0.35) {
            // Lowered threshold for better detection rate
            return face.copyWith(distance: similarity);
          }
          return null;
        }
      }
    }

    Recognition? ans;
    double bestSimilarity = 0.0; // Changed from minDistance to bestSimilarity

    for (Recognition entry in registered) {
      double similarity = calculateSimilarityScore(embedding, entry.embedding!);
      if (similarity > bestSimilarity) {
        // Looking for higher similarity score
        bestSimilarity = similarity;
        ans = entry.copyWith(distance: similarity);
      }
    }

    // Only return matches with minimum 35% similarity
    if (ans != null && bestSimilarity >= 0.35) {
      return ans;
    }
    return null;
  }

  // New method to calculate similarity in a consistent way
  double calculateSimilarityScore(List<double> emb1, List<double> emb2) {
    if (emb1.isEmpty || emb2.isEmpty) {
      print("ERROR: Empty embeddings can't be compared");
      return 0.0;
    }

    // Use a combination of multiple comparison methods for better results

    // 1. Cosine similarity
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    int minLength = math.min(emb1.length, emb2.length);

    for (int i = 0; i < minLength; i++) {
      // Add safeguards against NaN values
      double val1 = emb1[i].isFinite ? emb1[i] : 0.0;
      double val2 = emb2[i].isFinite ? emb2[i] : 0.0;

      dotProduct += val1 * val2;
      norm1 += val1 * val1;
      norm2 += val2 * val2;
    }

    // Avoid division by zero
    if (norm1 <= 0 || norm2 <= 0) {
      return 0.0;
    }

    double cosineSimilarity =
        dotProduct / (math.sqrt(norm1) * math.sqrt(norm2));

    // 2. Euclidean distance (L2)
    double l2Distance = 0.0;
    for (int i = 0; i < minLength; i++) {
      double diff = emb1[i] - emb2[i];
      l2Distance += diff * diff;
    }
    l2Distance = math.sqrt(l2Distance);

    // Convert distance to similarity (0 to 1 scale)
    double l2Similarity = 1.0 / (1.0 + l2Distance);

    // 3. Manhattan distance (L1) for additional comparison
    double l1Distance = 0.0;
    for (int i = 0; i < minLength; i++) {
      l1Distance += (emb1[i] - emb2[i]).abs();
    }

    // Convert L1 distance to similarity
    double l1Similarity = 1.0 / (1.0 + l1Distance / minLength);

    // 4. Combined similarity score with weighted average
    double combinedSimilarity =
        (cosineSimilarity * 0.6) + (l2Similarity * 0.3) + (l1Similarity * 0.1);

    // Applying a boost to increase similarity scores within a valid range
    double boostedSimilarity = math.pow(combinedSimilarity, 0.8).toDouble();

    // Ensure result is between 0 and 1
    return math.max(0.0, math.min(1.0, boostedSimilarity));
  }

  // Method to verify if multiple face embeddings belong to the same person
  Future<bool> verifyFaceMatching(
    List<List<double>> embeddings, {
    double threshold = 0.35,
  }) async {
    if (embeddings.length < 2) {
      return true; // Single image is always matching with itself
    }

    // Compare each pair of embeddings
    for (int i = 0; i < embeddings.length - 1; i++) {
      for (int j = i + 1; j < embeddings.length; j++) {
        double similarity = calculateSimilarityScore(
          embeddings[i],
          embeddings[j],
        );
        print(
          "Comparing faces $i and $j: ${(similarity * 100).toStringAsFixed(1)}% similarity",
        );

        if (similarity < threshold) {
          print(
            "Face mismatch detected: ${(similarity * 100).toStringAsFixed(1)}% similarity is below threshold of ${(threshold * 100).toStringAsFixed(1)}%",
          );
          return false;
        }
      }
    }

    return true;
  }

  // Method to verify if a face isn't already registered for someone else
  Future<bool> verifyNotRegistered(
    List<List<double>> embeddings, {
    double threshold = 0.50,
  }) async {
    if (registered.isEmpty || embeddings.isEmpty) {
      return true; // No registered faces, so no duplicates
    }

    // Average the new face embeddings
    List<double> averageEmbedding = _averageEmbeddings(embeddings);

    // Compare with all registered faces
    for (Recognition entry in registered) {
      double similarity = calculateSimilarityScore(
        averageEmbedding,
        entry.embedding!,
      );
      print(
        "Comparing with registered face ${entry.name} (${entry.studentId}): ${(similarity * 100).toStringAsFixed(1)}% similarity",
      );

      if (similarity >= threshold) {
        print(
          "Possible duplicate detected: ${(similarity * 100).toStringAsFixed(1)}% similarity with ${entry.name} (${entry.studentId})",
        );
        return false;
      }
    }

    return true;
  }

  findNearest(List<double> emb) {
    print('Finding nearest face match...');
    // Initialize with a VERY low similarity score
    Pair pair = Pair("Unknown", "unknown", 0.0);

    if (registered.isEmpty) {
      print('No faces registered in database');
      return pair;
    }

    print('Comparing with ${registered.length} registered faces');
    double bestSimilarity = 0.0;
    double secondBestSimilarity = 0.0;
    Recognition? bestMatch;

    // Print input embedding information for debugging
    double embNorm = 0;
    for (double val in emb) {
      embNorm += val * val;
    }
    embNorm = math.sqrt(embNorm);
    print('Input embedding norm: $embNorm');

    // Do a sanity check on the embedding vector
    if (embNorm < 0.001) {
      // More strict check (previously 0.01)
      print('WARNING: Input embedding has very small norm, likely invalid');
      return Pair("Error", "error", 0.0);
    }

    try {
      // Use consistent similarity calculation
      for (Recognition entry in registered) {
        if (entry.embedding == null || entry.embedding!.isEmpty) {
          print(
            'Skipping comparison with ${entry.name} due to invalid embedding',
          );
          continue;
        }

        double similarity = calculateSimilarityScore(emb, entry.embedding!);

        print(
          'Comparing with ${entry.name}: ' +
              'similarity=${(similarity * 100).toStringAsFixed(1)}%',
        );

        if (similarity > bestSimilarity) {
          secondBestSimilarity = bestSimilarity;
          bestSimilarity = similarity;
          bestMatch = entry;
          pair.distance = similarity;
          pair.name = entry.name;
          pair.studentId = entry.studentId;
        } else if (similarity > secondBestSimilarity) {
          secondBestSimilarity = similarity;
        }
      }

      // Check if best match is significantly better than second best (distinctiveness check)
      if (bestSimilarity > 0 && secondBestSimilarity > 0) {
        double distinctiveness = bestSimilarity / secondBestSimilarity;
        print('Best match distinctiveness ratio: $distinctiveness');

        // If the best match is not distinctive enough, apply a larger penalty
        if (distinctiveness < 1.5 && bestSimilarity < 0.75) {
          // Increased distinctiveness threshold to 1.5
          bestSimilarity *= 0.7; // Increased penalty (previously 0.9)
          pair.distance = bestSimilarity;
          print(
            'Applying distinctiveness penalty, adjusted score: ${(bestSimilarity * 100).toStringAsFixed(1)}%',
          );
        }
      }
    } catch (e) {
      print('Error during face comparison: $e');
      // Return very low similarity value on error
      return Pair("Error", "error", 0.0);
    }

    print(
      'Best match: ${pair.name} with similarity ${(pair.distance * 100).toStringAsFixed(1)}%',
    );
    return pair;
  }

  Future<void> registerFaceInDB(
    String name,
    List<double> embedding,
    String studentId,
  ) async {
    if (dbHelper == null) {
      dbHelper = DatabaseHelper();
      await dbHelper!.init();
    }

    // Primero verificamos si el estudiante ya está registrado
    final existingFace = await dbHelper!.queryStudentById(studentId);

    if (existingFace.isNotEmpty) {
      // Borramos el registro existente antes de agregar el nuevo
      await dbHelper!.deleteByStudentId(studentId);
      print("Deleted existing face record for student ID: $studentId");
    }

    print("Registering face for student ID: $studentId, Name: $name");
    final String embeddingStr = embedding.map((e) => e.toString()).join(',');
    final Map<String, dynamic> row = {
      DatabaseHelper.columnName: name,
      DatabaseHelper.columnEmbedding: embeddingStr,
      DatabaseHelper.columnStudentId: studentId,
    };

    final id = await dbHelper!.insert(row);
    print("Registered face with ID: $id");

    // Recargar las caras registradas después de agregar una nueva
    await _loadRegisteredFacesFromDB();
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset(modelName);
      print('Interpreter loaded successfully');
    } catch (e) {
      print('Unable to create interpreter, Caught Exception: ${e.toString()}');
    }
  }

  List<dynamic> imageToArray(img.Image inputImage) {
    img.Image resizedImage = img.copyResize(
      inputImage!,
      width: WIDTH,
      height: HEIGHT,
    );
    List<double> flattenedList =
        resizedImage.data!
            .expand((channel) => [channel.r, channel.g, channel.b])
            .map((value) => value.toDouble())
            .toList();
    Float32List float32Array = Float32List.fromList(flattenedList);
    int channels = 3;
    int height = HEIGHT;
    int width = WIDTH;
    Float32List reshapedArray = Float32List(1 * height * width * channels);
    for (int c = 0; c < channels; c++) {
      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          int index = c * height * width + h * width + w;
          reshapedArray[index] =
              (float32Array[c * height * width + h * width + w] - 127.5) /
              127.5;
        }
      }
    }
    return reshapedArray.reshape([1, 112, 112, 3]);
  }

  // Completely revised recognition method
  Recognition recognize(img.Image image, Rect location) {
    // Check if model is loaded
    if (!_modelLoaded) {
      print('Model not yet loaded, please wait');
      return Recognition("Not Ready", "unknown", [], 0.0);
    }

    try {
      // Apply image enhancement
      img.Image enhancedImage = _enhanceImageForRecognition(image);

      // Convert image to input array
      var input = imageToArray(enhancedImage);
      print('Input shape: ${input.shape}');

      // Prepare output array
      List output = List.filled(1 * 192, 0).reshape([1, 192]);

      // Perform inference multiple times and average results for better accuracy
      final int numInferences = 5; // Increased from 3 to 5
      List<List<double>> allOutputs = [];

      final startTime = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < numInferences; i++) {
        interpreter.run(input, output);
        List<double> currentOutput = List<double>.from(output.first);

        // Validate output values
        bool validOutput = true;
        for (double val in currentOutput) {
          if (!val.isFinite) {
            validOutput = false;
            break;
          }
        }

        if (validOutput) {
          allOutputs.add(currentOutput);
        }
      }

      final inferenceTime = DateTime.now().millisecondsSinceEpoch - startTime;
      print('Total inference time for $numInferences runs: $inferenceTime ms');

      if (allOutputs.isEmpty) {
        print('Error: No valid embeddings generated from inference');
        return Recognition("Error", "unknown", [], 0.0);
      }

      // Average all outputs
      List<double> averagedOutput = _averageEmbeddings(allOutputs);

      // Normalize the embedding
      _normalizeEmbedding(averagedOutput);

      // Apply post-processing to enhance the embedding quality
      _enhanceEmbedding(averagedOutput);

      // Find the nearest matching face
      Pair pair = findNearest(averagedOutput);
      print('Recognition distance: ${pair.distance}');

      // Create recognition result
      Recognition result = Recognition(
        pair.name,
        pair.studentId,
        averagedOutput,
        pair.distance,
      );

      // Print debug information
      print('Recognition result:');
      print('Name: ${result.name}');
      print('Student ID: ${result.studentId}');
      print('Distance: ${result.distance}');
      print(
        'Similarity percentage: ${(result.distance * 100).toStringAsFixed(1)}%',
      );

      return result;
    } catch (e) {
      print('Error during recognition: $e');
      // Return a meaningful error with 0.0 as the distance score
      return Recognition("Error", "unknown", [], 0.0);
    }
  }

  // New helper methods for image enhancement and embedding processing
  img.Image _enhanceImageForRecognition(img.Image original) {
    // Apply a series of enhancements to improve face recognition
    img.Image enhanced = original;

    // 1. Ensure correct size
    if (enhanced.width != WIDTH || enhanced.height != HEIGHT) {
      enhanced = img.copyResize(enhanced, width: WIDTH, height: HEIGHT);
    }

    // 2. Adjust color balance for better recognition
    enhanced = img.adjustColor(
      enhanced,
      saturation: 1.05, // Slightly increase saturation
      brightness: 1.05, // Slightly increase brightness
      contrast: 1.25, // Increase contrast
    );

    // 3. Apply additional adjustments for face recognition
    try {
      // Apply subtle sharpening to enhance facial features
      // enhanced = img.sharpen(enhanced, amount: 0.3); // Removed sharpen call
    } catch (e) {
      print('Error applying additional enhancements: $e');
    }

    return enhanced;
  }

  List<double> _averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];

    int embLength = embeddings.first.length;
    List<double> average = List<double>.filled(embLength, 0.0);

    for (var embedding in embeddings) {
      for (int i = 0; i < embLength; i++) {
        average[i] += embedding[i] / embeddings.length;
      }
    }

    return average;
  }

  void _normalizeEmbedding(List<double> embedding) {
    // L2 normalization to ensure unit vector
    double squaredSum = 0.0;
    for (double val in embedding) {
      squaredSum += val * val;
    }

    if (squaredSum > 0) {
      double norm = math.sqrt(squaredSum);
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= norm;
      }
    }
  }

  // New method to enhance embedding quality
  void _enhanceEmbedding(List<double> embedding) {
    // 1. Remove extremely small values that might be noise
    for (int i = 0; i < embedding.length; i++) {
      if (embedding[i].abs() < 1e-5) {
        embedding[i] = 0.0;
      }
    }

    // 2. Apply softmax-like normalization to enhance the dominant features
    double maxVal = 0.0;
    for (int i = 0; i < embedding.length; i++) {
      if (embedding[i].abs() > maxVal) {
        maxVal = embedding[i].abs();
      }
    }

    if (maxVal > 0) {
      // Enhance dominant features slightly
      for (int i = 0; i < embedding.length; i++) {
        double ratio = embedding[i].abs() / maxVal;
        // Use sigmoid-like function to enhance values
        double enhanceFactor = 1.0 + 0.2 * ratio;
        embedding[i] *= enhanceFactor;
      }

      // Re-normalize after enhancement
      _normalizeEmbedding(embedding);
    }
  }

  void close() {
    interpreter.close();
  }
}

class Pair {
  String name;
  String studentId;
  double distance;
  Pair(this.name, this.studentId, this.distance);
}
