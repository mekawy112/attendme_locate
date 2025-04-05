import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
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
      List<double> embd = row[DatabaseHelper.columnEmbedding]
          .split(',')
          .map((e) => double.parse(e))
          .toList()
          .cast<double>();
          
      print("Loaded face for student ID: $studentId, Name: $name");
      
      return Recognition(name, studentId, embd, 0);
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
        print("Processing row: ${row[DatabaseHelper.columnName]}");
        String name = row[DatabaseHelper.columnName];
        String studentId = row[DatabaseHelper.columnStudentId] ?? "unknown";
        List<double> embd = row[DatabaseHelper.columnEmbedding]
            .split(',')
            .map((e) => double.parse(e))
            .toList()
            .cast<double>();
        Recognition recognition = Recognition(name, studentId, embd, 0);
        registered.add(recognition);
        print("Registered face: $name (Student ID: $studentId) with ${embd.length} embedding points");
      } catch (e) {
        print("Error processing face record: $e");
      }
    }
  }
  
  // u0639u0645u0644u064au0629 u0627u0644u062au0639u0631u0641 u0639u0644u0649 u0627u0644u0648u062cu0648u0647 u0645u0639 u062au062du0633u064au0646u0627u062a u0644u0644u062au062du0642u0642 u0645u0646 u0645u0639u0631u0641 u0627u0644u0637u0627u0644u0628
  Recognition? recognizeFace(List<double> embedding, String? studentId) {
    if (studentId != null && registered.isNotEmpty) {
      for (Recognition face in registered) {
        if (face.studentId == studentId) {
          double similarity = face.calculateSimilarity(embedding);
          print("Checking face for specific student ID: $studentId, Similarity: $similarity");
          
          if (similarity >= 0.5) { 
            return face.copyWith(distance: similarity);
          }
          return null;
        }
      }
    }

    Recognition? ans;
    double minDistance = 999;

    for (Recognition entry in registered) {
      double similarity = entry.calculateSimilarity(embedding);
      if (similarity < minDistance) {
        minDistance = similarity;
        ans = entry.copyWith(distance: similarity);
      }
    }
    
    if (ans != null && minDistance <= 0.6) { 
      return ans;
    }
    return null;
  }

  findNearest(List<double> emb) {
    print('Finding nearest face match...');
    Pair pair = Pair("Unknown", "unknown", -5);
    
    if (registered.isEmpty) {
      print('No faces registered in database');
      return pair;
    }
    
    print('Comparing with ${registered.length} registered faces');
    double bestDistance = -1;
    
    for (Recognition entry in registered) {
      double similarity = entry.calculateSimilarity(emb);
      print('Comparing with ${entry.name}: similarity = ${(similarity * 100).toStringAsFixed(1)}%');
      
      if (similarity > bestDistance) {
        bestDistance = similarity;
        pair.distance = similarity;
        pair.name = entry.name;
        pair.studentId = entry.studentId;
      }
    }
    
    print('Best match: ${pair.name} with similarity ${(pair.distance * 100).toStringAsFixed(1)}%');
    return pair;
  }

  Future<void> registerFaceInDB(String name, List<double> embedding, String studentId) async {
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
    img.Image resizedImage =
    img.copyResize(inputImage!, width: WIDTH, height: HEIGHT);
    List<double> flattenedList = resizedImage.data!
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

  Recognition recognize(img.Image image, Rect location) {
    // Check if model is loaded
    if (!_modelLoaded) {
      print('Model not yet loaded, please wait');
      return Recognition("Not Ready", "unknown", [], -1);
    }
    
    try {
      // Convert image to input array
      var input = imageToArray(image);
      print('Input shape: ${input.shape}');

      // Prepare output array
      List output = List.filled(1 * 192, 0).reshape([1, 192]);

      // Perform inference
      final startTime = DateTime.now().millisecondsSinceEpoch;
      interpreter.run(input, output);
      final inferenceTime = DateTime.now().millisecondsSinceEpoch - startTime;
      print('Inference time: $inferenceTime ms');

      // Convert output to double list
      List<double> outputArray = output.first.cast<double>();

      // Find the nearest matching face
      Pair pair = findNearest(outputArray);
      print('Recognition distance: ${pair.distance}');

      // Create recognition result
      Recognition result = Recognition(pair.name, pair.studentId, outputArray, pair.distance);
      
      // Print debug information
      print('Recognition result:');
      print('Name: ${result.name}');
      print('Student ID: ${result.studentId}');
      print('Distance: ${result.distance}');
      
      return result;
    } catch (e) {
      print('Error during recognition: $e');
      return Recognition("Error", "unknown", [], -1);
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