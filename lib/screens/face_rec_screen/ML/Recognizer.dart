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
  Map<String, Recognition> registered = Map();
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
      
      return Recognition(name, Rect.zero, embd, 0);
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
        Recognition recognition =
        Recognition(name, Rect.zero, embd, 0);
        registered.putIfAbsent(studentId, () => recognition); // u0627u0633u062au062eu062fu0627u0645 u0645u0639u0631u0641 u0627u0644u0637u0627u0644u0628 u0643u0645u0641u062au0627u062d u0628u062fu0644u0627u064b u0645u0646 u0627u0644u0627u0633u0645
        print("Registered face: $name (Student ID: $studentId) with ${embd.length} embedding points");
      } catch (e) {
        print("Error processing face record: $e");
      }
    }
  }
  
  // u0639u0645u0644u064au0629 u0627u0644u062au0639u0631u0641 u0639u0644u0649 u0627u0644u0648u062cu0648u0647 u0645u0639 u062au062du0633u064au0646u0627u062a u0644u0644u062au062du0642u0642 u0645u0646 u0645u0639u0631u0641 u0627u0644u0637u0627u0644u0628
  Recognition? recognizeFace(List<double> embedding, String? studentId) {
    // u0625u0630u0627 u062au0645 u062au0648u0641u064au0631 u0645u0639u0631u0641 u0627u0644u0637u0627u0644u0628u060c u0627u0644u062au062du0642u0642 u0641u0642u0637 u0645u0646 u0648u062cu0647 u0647u0630u0627 u0627u0644u0637u0627u0644u0628
    if (studentId != null && registered.containsKey(studentId)) {
      Recognition storedFace = registered[studentId]!;
      double similarity = _calculateSimilarity(embedding, storedFace.embedding!);
      print("Checking face for specific student ID: $studentId, Similarity: $similarity");
      
      if (similarity >= 0.5) { 
        return storedFace.copyWith(distance: similarity);
      }
      return null;
    }

    // u0625u0630u0627 u0644u0645 u064au062au0645 u062au0648u0641u064au0631 u0645u0639u0631u0641 u0627u0644u0637u0627u0644u0628u060c u062au062du0642u0642 u0645u0646 u062cu0645u064au0639 u0627u0644u0648u062cu0648u0647 u0627u0644u0645u0633u062cu0644u0629
    Recognition? ans;
    double minDistance = 999;

    for (Recognition entry in registered.values) {
      double distance = _calculateSimilarity(embedding, entry.embedding!);
      if (distance < minDistance) {
        minDistance = distance;
        ans = entry.copyWith(distance: distance);
      }
    }
    
    // u0627u0644u062au062du0642u0642 u0645u0646 u0623u0646 u0627u0644u062au0634u0627u0628u0647 u0641u0648u0642 u0627u0644u062du062f u0627u0644u0623u062fu0646u0649
    if (ans != null && minDistance <= 0.6) { 
      return ans;
    }
    return null;
  }
  
  // u062du0633u0627u0628 u062au0634u0627u0628u0647 u062cu064au0628 u0627u0644u062au0645u0627u0645 u0628u064au0646 u0645u062au062cu0647u064au0646
  double _calculateSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length) {
      throw Exception('Vector dimensions do not match');
    }
    
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }
    
    return dotProduct / (math.sqrt(norm1) * math.sqrt(norm2));
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
    //Check if model is loaded
    if (!_modelLoaded) {
      print('Model not yet loaded, please wait');
      return Recognition("Not Ready", location, [], -1);
    }
    
    //TODO crop face from image resize it and convert it to float array
    var input = imageToArray(image);
    print(input.shape.toString());

    //TODO output array
    List output = List.filled(1 * 192, 0).reshape([1, 192]);

    try {
      //TODO performs inference
      final runs = DateTime.now().millisecondsSinceEpoch;
      interpreter.run(input, output);
      final run = DateTime.now().millisecondsSinceEpoch - runs;
      print('Time to run inference: $run ms$output');

      //TODO convert dynamic list to double list
      List<double> outputArray = output.first.cast<double>();

      //TODO looks for the nearest embeeding in the database and returns the pair
      Pair pair = findNearest(outputArray);
      print("distance= ${pair.distance}");

      return Recognition(pair.name, location, outputArray, pair.distance);
    } catch (e) {
      print('Error in recognition: ${e.toString()}');
      return Recognition("Error", location, [], -1);
    }
  }

  //TODO  looks for the nearest embeeding in the database and returns the pair which contain information of registered face with which face is most similar
  findNearest(List<double> emb) {
    Pair pair = Pair("Unknown", -5);
    print("Searching among ${registered.entries.length} registered faces");
    
    if (registered.entries.isEmpty) {
      print("No registered faces found in database!");
      return pair;
    }
    
    for (MapEntry<String, Recognition> item in registered.entries) {
      final String name = item.key;
      List<double>? knownEmb = item.value.embedding; // Cambiar embeddings a embedding
      
      // Verificar si knownEmb es null
      if (knownEmb == null) {
        print("Warning: Null embedding found for $name");
        continue;
      }
      
      double distance = 0;
      for (int i = 0; i < emb.length; i++) {
        double diff = emb[i] - knownEmb[i];
        distance += diff * diff;
      }
      distance = math.sqrt(distance);
      print("Compared with $name: distance = $distance");
      if (pair.distance == -5 || distance < pair.distance) {
        pair.distance = distance;
        pair.name = name;
      }
    }
    return pair;
  }

  void close() {
    interpreter.close();
  }
}

class Pair {
  String name;
  double distance;
  Pair(this.name, this.distance);
}