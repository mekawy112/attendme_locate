import 'dart:ui' as ui;
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:attend_me_locate/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theming/colors.dart';
import '../../services/api_service.dart';

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
      var id = widget.studentData!['id'];
      return id?.toString(); 
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
    // Check that _image is not null before continuing
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No faces detected"), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
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

      // Add debug information to know the values used
      print("Face detection coordinates: Left: $left, Top: $top, Width: $width, Height: $height");

      // Ensure image file exists before reading bytes
      if (_image == null || !_image!.existsSync()) {
        print("Error: Image file doesn't exist or is null");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: Image file not available"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
              const SnackBar(
                content: Text("Error: Could not decode image format"),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
        } catch (decodeError) {
          print("Secondary decode error: $decodeError");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: Failed to process image"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
      
      // Add additional check for dimensions
      if (width <= 0 || height <= 0 || left < 0 || top < 0 || left >= faceImg.width || top >= faceImg.height) {
        print("Error: Invalid crop dimensions. Face coordinates: $left, $top, $width, $height. Image dimensions: ${faceImg.width}x${faceImg.height}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: Invalid face dimensions detected"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
      
      // Add debug information for recognition
      print("Recognition result: Name=${recognition.name}, Distance=${recognition.distance}");

      // Show result with option to re-register if result is weak or incorrect
      showRecognitionResultDialog(
        Uint8List.fromList(img.encodeBmp(croppedFace)),
        recognition,
      );
      
      // If face is recognized successfully, show welcome message
      if (recognition.name.isNotEmpty && recognition.name != "Unknown" && recognition.distance > 0.5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Welcome ${recognition.name}! Face verification successful."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Send face verification result to the server
        _sendFaceVerificationToServer();
      }
    } catch (e) {
      print("Error in cropAndRegisterFace: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: Face processing failed"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Add this new method to send face verification to server
  Future<bool> _sendFaceVerificationToServer() async {
    try {
      // Use the _studentId getter to consistently get the ID
      String? studentId = _studentId;
      
      if (studentId == null || studentId.isEmpty) {
        print('Error: No student ID available');
        return false;
      }
      
      print('Sending face verification for student ID: $studentId');
      
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/attendance/verify-face'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'face_verified': true,
          'verification_time': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('Face verification sent successfully');
        
        // If we have a courseId, also send attendance verification
        if (widget.courseId != null && widget.courseId!.isNotEmpty) {
          print('Sending attendance verification for course: ${widget.courseId}');
          
          final attendanceResponse = await http.post(
            Uri.parse('${ApiService.baseUrl}/attendance/verify'),
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
        
        // If no courseId, just verify the face
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
    
    // أضف تصحيح أخطاء إضافي
    print("Student data content: ${widget.studentData}");
    
    if (widget.studentData != null && widget.studentData!.isNotEmpty) {
      studentName = widget.studentData!['name'] ?? recognition.name;
      print("Using student name from data: $studentName");
    } else {
      studentName = recognition.name;
      print("Using recognition name: $studentName");
    }
    
    print("Recognition threshold check: isRecognized=$isRecognized, name=${recognition.name}, distance=${recognition.distance}");
    print("Student data: Name=$studentName, ID=$studentId");

    showDialog(
      context: context,
      barrierDismissible: false, // منع الإغلاق بالضغط خارج النافذة
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
                  ? "Face verification successful!\n\nStudent: $studentName\nSimilarity: ${(recognition.distance * 100).toStringAsFixed(2)}%\nID: $studentId"
                  : "Face not recognized or low similarity. Please register again.",
              style: TextStyle(

                  fontSize: 18, fontWeight: isRecognized ? FontWeight.bold : FontWeight.normal, color: isRecognized ? ColorsManager.darkBlueColor1 : Colors.red),
              textAlign: TextAlign.center,
            ),
            if (widget.courseId != null && widget.courseId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  "Course ID: ${widget.courseId}",
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
                      const SnackBar(
                        content: Text("Face verification sent successfully"),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Error sending face verification"),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                });
                Navigator.pop(context, true); // إرجاع true للشاشة السابقة
              } else {
                // إذا لم يتم التعرف، يمكننا أيضًا العودة بقيمة false للشاشة السابقة
                Navigator.pop(context, false);
              }
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
                  // Obtener el studentId o usar un valor predeterminado
                  String studentId = widget.studentData?['id'] ?? 'unknown';
                  
                  // Verificar que embedding no sea null
                  if (recognition.embedding == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No facial data available. Please try again."),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
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
                    const SnackBar(
                      content: Text("Face registered successfully"),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsManager.darkBlueColor1,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: const Text("Face Recognition",style: TextStyle(
          fontSize: 20,
          color: Colors.white
      ),), backgroundColor: ColorsManager.darkBlueColor1,
        leading: BackButton(
          color: Colors.white,
        ),),
      resizeToAvoidBottomInset: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: 10.sp,
          ),
           Text('Take photo of your face', style: TextStyle(
             fontSize: 24,
             color: ColorsManager.darkBlueColor1,
             fontWeight: FontWeight.bold
           ),),
          _image != null && image != null
              ? Container(
            height: 290,
            margin: const EdgeInsets.only(
              top: 0,
              left: 30,
              right: 30,
              bottom: 120,
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
            margin: const EdgeInsets.only(top: 15),
            child: Icon(
              Icons.person_pin_rounded,
              size: screenWidth - 120,
              color: ColorsManager.darkBlueColor1,
            ),
          ),
          Container(height: 90),
          // Image capture buttons section

          AppButton(buttonText: 'Capture', onPressed: (){
            _imgFromCamera();
          }),
          SizedBox(
            height: 20.sp,
          )
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
