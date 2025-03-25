import 'dart:math';
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
  final dbHelper = DatabaseHelper();
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
    await dbHelper.init();
    await loadRegisteredFaces();
    print("Database initialized with ${registered.length} registered faces");
  }

  Future<void> loadRegisteredFaces() async {
    registered.clear();
    final allRows = await dbHelper.queryAllRows();
    print("Loading registered faces: ${allRows.length} records found");
    
    for (final row in allRows) {
      try {
        print("Processing row: ${row[DatabaseHelper.columnName]}");
        String name = row[DatabaseHelper.columnName];
        List<double> embd = row[DatabaseHelper.columnEmbedding]
            .split(',')
            .map((e) => double.parse(e))
            .toList()
            .cast<double>();
        Recognition recognition =
        Recognition(row[DatabaseHelper.columnName], Rect.zero, embd, 0);
        registered.putIfAbsent(name, () => recognition);
        print("Registered face: $name with ${embd.length} embedding points");
      } catch (e) {
        print("Error processing face record: $e");
      }
    }
  }

  void registerFaceInDB(String name, List<double> embedding) async {
    // row to insert
    Map<String, dynamic> row = {
      DatabaseHelper.columnName: name,
      DatabaseHelper.columnEmbedding: embedding.join(",")
    };
    final id = await dbHelper.insert(row);
    print('inserted row id: $id');
    loadRegisteredFaces();
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
      List<double> knownEmb = item.value.embeddings;
      double distance = 0;
      for (int i = 0; i < emb.length; i++) {
        double diff = emb[i] - knownEmb[i];
        distance += diff * diff;
      }
      distance = sqrt(distance);
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