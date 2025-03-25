import 'dart:ui' as ui;
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'ML/Recognition.dart';
import 'ML/Recognizer.dart';

class RecognitionScreen extends StatefulWidget {
  final Map<String, dynamic>? studentData;
  final String? studentId;
  final String? courseId;

  const RecognitionScreen({
    Key? key, 
    this.studentData,
    this.studentId,
    this.courseId,
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
  
  String? get _studentId {
    if (widget.studentData != null && widget.studentData!.containsKey('id')) {
      return widget.studentData!['id'];
    } else {
      return widget.studentId;
    }
  }

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();

    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    );
    faceDetector = FaceDetector(options: options);

    recognizer = Recognizer();
    _initRecognizer();
  }
  
  Future<void> _initRecognizer() async {
    try {
      await recognizer.loadRegisteredFaces();
      print('Recognizer initialized with ${recognizer.registered.length} registered faces');
    } catch (e) {
      print('Error initializing recognizer: $e');
    }
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
    // Verificar que _image no sea nulo antes de continuar
    if (_image != null) {
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
  }

  // Crop face, extract embedding and show result
  cropAndRegisterFace(Rect boundingBox) {
    try {
      num left = boundingBox.left < 0 ? 0 : boundingBox.left;
      num top = boundingBox.top < 0 ? 0 : boundingBox.top;
      num right =
      boundingBox.right > image!.width ? image!.width - 1 : boundingBox.right;
      num bottom = boundingBox.bottom > image!.height
          ? image!.height - 1
          : boundingBox.bottom;
      num width = right - left;
      num height = bottom - top;

      // أضف معلومات تصحيح أخطاء لمعرفة القيم المستخدمة
      print("Face detection coordinates: Left: $left, Top: $top, Width: $width, Height: $height");

      // Ensure image file exists before reading bytes
      if (_image == null || !_image!.existsSync()) {
        print("Error: Image file doesn't exist or is null");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Image file not available")),
        );
        return;
      }
      
      final bytes = _image!.readAsBytesSync();
      img.Image? faceImg = img.decodeImage(bytes);
      
      if (faceImg == null) {
        // Try alternative approach to decode image
        try {
          // Try with a different decoder or approach
          Uint8List imageBytes = _image!.readAsBytesSync();
          faceImg = img.decodeJpg(imageBytes) ?? img.decodePng(imageBytes);
          
          if (faceImg == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error processing image: Could not decode image format")),
            );
            return;
          }
        } catch (decodeError) {
          print("Secondary decode error: $decodeError");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error processing image: $decodeError")),
          );
          return;
        }
      }
      
      // أضف فحصًا إضافيًا للأبعاد
      if (width <= 0 || height <= 0 || left < 0 || top < 0 || left >= faceImg.width || top >= faceImg.height) {
        print("Error: Invalid crop dimensions. Face coordinates: $left, $top, $width, $height. Image dimensions: ${faceImg.width}x${faceImg.height}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid face dimensions detected")),
        );
        return;
      }
      
      img.Image croppedFace = img.copyCrop(
        faceImg,
        x: left.toInt(),
        y: top.toInt(),
        width: width.toInt(),
        height: height.toInt(),
      );

      // Call the function that performs face recognition
      Recognition recognition = recognizer.recognize(croppedFace, boundingBox);
      
      // أضف معلومات تصحيح أخطاء للتعرف
      print("Recognition result: Name=${recognition.name}, Distance=${recognition.distance}");

      // Show result with option to re-register if result is weak or incorrect
      showRecognitionResultDialog(
        Uint8List.fromList(img.encodeBmp(croppedFace)),
        recognition,
      );
      
      // If face is recognized successfully, show welcome message
      if (recognition.name.isNotEmpty && recognition.name != "Unknown" && recognition.distance > 0.5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome ${recognition.name}! Face verification successful.")),
        );
        
        // Send face verification result to the server
        _sendFaceVerificationToServer();
      }
    } catch (e) {
      print("Error in cropAndRegisterFace: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error processing face: $e")),
      );
    }
  }

  // Add this new method to send face verification to server
  Future<bool> _sendFaceVerificationToServer() async {
    try {
      // Usar el getter _studentId para obtener el ID consistentemente
      String? studentId = _studentId;
      
      if (studentId == null || studentId.isEmpty) {
        print('Error: No student ID available');
        return false;
      }
      
      print('Enviando verificación facial para studentId: $studentId');
      
      final response = await http.post(
        Uri.parse('http://192.168.1.68:5000/attendance/verify-face'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'face_verified': true,
          'verification_time': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('Face verification sent successfully');
        
        // Si tenemos un courseId, también enviamos la verificación de asistencia
        if (widget.courseId != null && widget.courseId!.isNotEmpty) {
          print('Sending attendance verification for course: ${widget.courseId}');
          
          final attendanceResponse = await http.post(
            Uri.parse('http://192.168.1.68:5000/attendance/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'student_id': studentId, 
              'course_id': widget.courseId,
              'face_verified': true,
            }),
          );
          
          print('Attendance verify response: ${attendanceResponse.statusCode}');
          print('Response body: ${attendanceResponse.body}');
          
          return attendanceResponse.statusCode == 200;
        }
        
        // Si no hay courseId, solo verificamos el rostro
        return true;
      } else {
        print('Error sending face verification: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception sending face verification: $e');
      return false;
    }
  }

  // Remove rotation function (modifies image on file)
  removeRotation(File? inputImage) async {
    if (inputImage != null && inputImage.existsSync()) {
      try {
        final img.Image? capturedImage =
            img.decodeImage(await inputImage.readAsBytes());
        if (capturedImage != null) {
          final img.Image orientedImage = img.bakeOrientation(capturedImage);
          await inputImage.writeAsBytes(img.encodeJpg(orientedImage));
          print("Image rotation corrected successfully");
        } else {
          print("Error: Could not decode image for rotation correction");
        }
      } catch (e) {
        print("Error in removeRotation: $e");
      }
    }
  }

  // Show recognition result with "Register Again" option
  showRecognitionResultDialog(Uint8List croppedFace, Recognition recognition) {
    // لتسهيل التجربة، سنعتبر أي تعرف بنسبة تشابه أكبر من 0.5 صالحًا
    // يمكن ضبط هذه القيمة حسب احتياجات التطبيق
    double similarityThreshold = 0.5;
    bool isRecognized = recognition.name.isNotEmpty && 
                        recognition.name != "Unknown" && 
                        recognition.distance > similarityThreshold;
    
    // Obtener el nombre real del estudiante a partir de los datos almacenados
    String studentName = "";
    String studentId = _studentId ?? "";
    
    if (widget.studentData != null && widget.studentData!.isNotEmpty) {
      studentName = widget.studentData!["name"] ?? recognition.name;
    } else {
      studentName = recognition.name;
    }
    
    print("Recognition threshold check: isRecognized=$isRecognized, name=${recognition.name}, distance=${recognition.distance}");
    print("Student data: Name=$studentName, ID=$studentId");

    showDialog(
      context: context,
      barrierDismissible: false, // منع الإغلاق بالضغط خارج النافذة
      builder: (ctx) => AlertDialog(
        title: const Text(
          "نتيجة التعرف على الوجه",
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(croppedFace, width: 200, height: 200),
            const SizedBox(height: 10),
            Text(
              isRecognized
                  ? "الطالب: $studentName\nنسبة التشابه: ${(recognition.distance * 100).toStringAsFixed(2)}%\nID: $studentId"
                  : "لم يتم التعرف على الوجه أو نسبة التشابه منخفضة. الرجاء التسجيل مرة أخرى.",
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            if (widget.courseId != null && widget.courseId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  "Curso ID: ${widget.courseId}",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
        actions: [
          // "OK" button to close window
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // إذا كان التعرف ناجحًا، أخبر الشاشة السابقة
              if (isRecognized) {
                // Enviar verificación facial al servidor antes de cerrar
                _sendFaceVerificationToServer().then((success) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Verificación facial enviada correctamente")),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error al enviar verificación facial")),
                    );
                  }
                });
                Navigator.pop(context, true); // إرجاع true للشاشة السابقة
              } else {
                // إذا لم يتم التعرف، يمكننا أيضًا العودة بقيمة false للشاشة السابقة
                Navigator.pop(context, false);
              }
            },
            child: const Text("موافق"),
          ),
          // "Register Again" button to re-register and correct name
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Open registration window with cropped face
              showFaceRegistrationDialogue(croppedFace, recognition);
            },
            child: const Text("تسجيل مرة أخرى"),
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
                  // Obtener el studentId o usar un valor predeterminado
                  String studentId = widget.studentData?['id'] ?? 'unknown';
                  
                  // Verificar que embedding no sea null
                  if (recognition.embedding == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No se pudo obtener datos faciales. Intente de nuevo.")),
                    );
                    return;
                  }
                  
                  recognizer.registerFaceInDB(
                    textEditingController.text,
                    recognition.embedding!, // Usar el operador ! para indicar que no es null
                    studentId,
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
