import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import 'ML/Recognition.dart';
import 'ML/Recognizer.dart';

class RecognitionScreen extends StatefulWidget {
  final Map<String, dynamic>? studentData;
  final String? studentId;

  const RecognitionScreen({
    Key? key, 
    this.studentData,
    this.studentId,
  }) : super(key: key);

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  late ImagePicker imagePicker;
  File? _image;

  late FaceDetector faceDetector;
  late Recognizer recognizer;

  ui.Image? image; // Image to display in the interface

  List<Face> faces = [];

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();

    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    );
    faceDetector = FaceDetector(options: options);

    recognizer = Recognizer();
  }

  // Capture image from camera
  _imgFromCamera() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      _image = File(pickedFile.path);
      final data = await _image!.readAsBytes();
      ui.decodeImageFromList(data, (ui.Image img) {
        setState(() {
          image = img; // Initialize image for display
          doFaceDetection();
        });
      });
    }
  }

  // Get image from gallery
  _imgFromGallery() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _image = File(pickedFile.path);
      final data = await _image!.readAsBytes();
      ui.decodeImageFromList(data, (ui.Image img) {
        setState(() {
          image = img; // Initialize image for display
          doFaceDetection();
        });
      });
    }
  }

  // Face detection function
  doFaceDetection() async {
    // Remove rotation before detection
    await removeRotation(_image!);

    InputImage inputImage = InputImage.fromFile(_image!);

    // Pass the image to face detector and get detected faces
    faces = await faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      for (Face face in faces) {
        cropAndRegisterFace(face.boundingBox);
      }
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No faces detected")));
    }
  }

  // Crop face, extract embedding and show result
  cropAndRegisterFace(Rect boundingBox) {
    num left = boundingBox.left < 0 ? 0 : boundingBox.left;
    num top = boundingBox.top < 0 ? 0 : boundingBox.top;
    num right =
    boundingBox.right > image!.width ? image!.width - 1 : boundingBox.right;
    num bottom = boundingBox.bottom > image!.height
        ? image!.height - 1
        : boundingBox.bottom;
    num width = right - left;
    num height = bottom - top;

    final bytes = _image!.readAsBytesSync();
    img.Image? faceImg = img.decodeImage(bytes);
    img.Image croppedFace = img.copyCrop(
      faceImg!,
      x: left.toInt(),
      y: top.toInt(),
      width: width.toInt(),
      height: height.toInt(),
    );

    // Call the function that performs face recognition
    Recognition recognition = recognizer.recognize(croppedFace, boundingBox);

    // Show result with option to re-register if result is weak or incorrect
    showRecognitionResultDialog(
      Uint8List.fromList(img.encodeBmp(croppedFace)),
      recognition,
    );
  }

  // Remove rotation function (modifies image on file)
  removeRotation(File inputImage) async {
    final img.Image? capturedImage =
    img.decodeImage(await File(inputImage.path).readAsBytes());
    final img.Image orientedImage = img.bakeOrientation(capturedImage!);
    await File(_image!.path).writeAsBytes(img.encodeJpg(orientedImage));
  }

  // Show recognition result with "Register Again" option
  showRecognitionResultDialog(Uint8List croppedFace, Recognition recognition) {
    // Can add a threshold condition here if a threshold value is available
    bool isRecognized = recognition.name.isNotEmpty && recognition.name != "Unknown"; // Or add a condition to ensure high similarity

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Recognition Result",
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(croppedFace, width: 200, height: 200),
            const SizedBox(height: 10),
            Text(
              isRecognized
                  ? "Student: ${recognition.name}\nSimilarity: ${recognition.distance.toStringAsFixed(2)}"
                  : "Face not recognized or similarity is low. Please register again.",
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          // "OK" button to close window
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text("OK"),
          ),
          // "Register Again" button to re-register and correct name
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Open registration window with cropped face
              showFaceRegistrationDialogue(croppedFace, recognition);
            },
            child: const Text("Register Again"),
          ),
        ],
      ),
    );
  }

  // Show registration dialog to correct name and re-register
  TextEditingController textEditingController = TextEditingController();
  showFaceRegistrationDialogue(Uint8List croppedFace, Recognition recognition) {
    // Pre-populate with student ID if available
    if (widget.studentId != null) {
      textEditingController.text = widget.studentId!;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Face Registration", textAlign: TextAlign.center),
        alignment: Alignment.center,
        content: SizedBox(
          height: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Image.memory(croppedFace, width: 200, height: 200),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: textEditingController,
                  decoration: const InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    hintText: "Enter Name/ID",
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  recognizer.registerFaceInDB(
                    textEditingController.text,
                    recognition.embeddings,
                  );
                  textEditingController.text = "";
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Face Registered")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(200, 40),
                ),
                child: const Text("Register"),
              ),
            ],
          ),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        backgroundColor: Colors.blue.shade800,
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _image != null && image != null
              ? Container(
            margin: const EdgeInsets.only(
              top: 60,
              left: 30,
              right: 30,
              bottom: 0,
            ),
            child: FittedBox(
              child: SizedBox(
                width: image!.width.toDouble(),
                height: image!.width.toDouble(),
                child: CustomPaint(
                  painter: FacePainter(facesList: faces, imageFile: image),
                ),
              ),
            ),
          )
              : Container(
            margin: const EdgeInsets.only(top: 100),
            child: Icon(
              Icons.face,
              size: screenWidth - 100,
              color: Colors.blue.shade200,
            ),
          ),
          Container(height: 50),
          // Image capture buttons section
          Container(
            margin: const EdgeInsets.only(bottom: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Card(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(200)),
                  ),
                  child: InkWell(
                    onTap: () {
                      _imgFromGallery();
                    },
                    child: SizedBox(
                      width: screenWidth / 2 - 70,
                      height: screenWidth / 2 - 70,
                      child: Icon(
                        Icons.image,
                        color: Colors.blue,
                        size: screenWidth / 7,
                      ),
                    ),
                  ),
                ),
                Card(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(200)),
                  ),
                  child: InkWell(
                    onTap: () {
                      _imgFromCamera();
                    },
                    child: SizedBox(
                      width: screenWidth / 2 - 70,
                      height: screenWidth / 2 - 70,
                      child: Icon(
                        Icons.camera,
                        color: Colors.blue,
                        size: screenWidth / 7,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  List<Face> facesList;
  ui.Image? imageFile;
  FacePainter({required this.facesList, @required this.imageFile});

  @override
  void paint(Canvas canvas, Size size) {
    if (imageFile != null) {
      canvas.drawImage(imageFile!, Offset.zero, Paint());
    }
    Paint p = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (Face face in facesList) {
      canvas.drawRect(face.boundingBox, p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
