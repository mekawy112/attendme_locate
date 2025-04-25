import 'dart:ui' as ui;
import 'dart:math' as math;
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
import 'RegistrationScreen.dart';
import 'DB/DatabaseHelper.dart';

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
  late DatabaseHelper databaseHelper;

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
    databaseHelper = DatabaseHelper();
    databaseHelper.init();

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
      print(
        'Recognizer initialized with ${recognizer.registered.length} registered faces',
      );
    } catch (e) {
      print('Error initializing recognizer: $e');
    }
  }

  // Capture image from camera
  _imgFromCamera() async {
    XFile? pickedFile = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
      maxWidth: 1200,
      maxHeight: 1200,
      preferredCameraDevice: CameraDevice.front,
    );
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
    XFile? pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
    );
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
    setState(() {
      faces = []; // Clear previous faces
    });

    // Check that _image is not null before continuing
    if (_image != null) {
      try {
        // Remove rotation before detection
        await removeRotation(_image!);

        InputImage inputImage = InputImage.fromFile(_image!);

        // Pass the image to face detector and get detected faces
        faces = await faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          print("Detected ${faces.length} faces");
          setState(() {}); // Update UI to show face rectangles

          for (Face face in faces) {
            cropAndRegisterFace(face.boundingBox);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No faces detected"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        print("Error in face detection: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error detecting face: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Completely revised face recognition process
  Future<void> cropAndRegisterFace(Rect boundingBox) async {
    try {
      // Ensure we have a valid image
      if (_image == null || !_image!.existsSync() || image == null) {
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

      // Extract coordinates for cropping
      num left = boundingBox.left < 0 ? 0 : boundingBox.left;
      num top = boundingBox.top < 0 ? 0 : boundingBox.top;
      num right =
          boundingBox.right > image!.width
              ? image!.width - 1
              : boundingBox.right;
      num bottom =
          boundingBox.bottom > image!.height
              ? image!.height - 1
              : boundingBox.bottom;
      num width = right - left;
      num height = bottom - top;

      print(
        "Face coordinates: Left: $left, Top: $top, Width: $width, Height: $height",
      );

      if (width <= 0 || height <= 0) {
        print("Invalid face dimensions");
        return;
      }

      // Read and decode the image
      final bytes = await _image!.readAsBytes();
      img.Image? faceImg = img.decodeImage(bytes);

      if (faceImg == null) {
        print("Failed to decode image");
        return;
      }

      // Crop the face - expanding the box by 10% to include more context
      int expandedWidth = ((width) * 1.1).toInt();
      int expandedHeight = ((height) * 1.1).toInt();

      // Calculate center point
      int centerX = (left + right).toInt() ~/ 2;
      int centerY = (top + bottom).toInt() ~/ 2;

      // Recalculate bounds with expansion
      left = math.max(0, centerX - expandedWidth ~/ 2);
      top = math.max(0, centerY - expandedHeight ~/ 2);
      width = math.min(expandedWidth, faceImg.width - left);
      height = math.min(expandedHeight, faceImg.height - top);

      img.Image croppedFace = img.copyCrop(
        faceImg,
        x: left.toInt(),
        y: top.toInt(),
        width: width.toInt(),
        height: height.toInt(),
      );

      // Apply image enhancements to improve recognition quality
      croppedFace = _enhanceFaceImage(croppedFace);

      // Resize to expected dimensions for the model
      croppedFace = img.copyResize(croppedFace, width: 112, height: 112);

      // Prepare a cropped face image for UI display
      Uint8List croppedBytes = Uint8List.fromList(img.encodeBmp(croppedFace));

      // Initialize recognition as null first
      Recognition? recognition;

      // Check if we have student ID to load specific face
      if (_studentId != null && _studentId!.isNotEmpty) {
        // First try to load the student's registered face from DB
        print("Looking for registered face with ID: $_studentId");
        recognition = await recognizer.loadFaceByStudentId(_studentId!);

        if (recognition != null) {
          print("Found registered face for student ID: $_studentId");

          // Try multiple recognition attempts for better accuracy
          List<Recognition> recognitionAttempts = [];
          List<double> similarities = [];

          // Perform multiple recognition attempts with slight variations
          for (int i = 0; i < 5; i++) {
            // Apply slightly different enhancements for each attempt
            img.Image enhancedCopy = _applyRandomEnhancements(croppedFace, i);
            Recognition attempt = recognizer.recognize(
              enhancedCopy,
              boundingBox,
            );

            if (attempt.embedding != null && recognition.embedding != null) {
              double similarity = recognizer.calculateSimilarityScore(
                recognition.embedding!,
                attempt.embedding!,
              );

              recognitionAttempts.add(attempt);
              similarities.add(similarity);
              print(
                "Recognition attempt #$i similarity: ${(similarity * 100).toStringAsFixed(1)}%",
              );
            }
          }

          if (recognitionAttempts.isNotEmpty) {
            // Find the best matching attempt
            int bestIndex = 0;
            double bestSimilarity = similarities[0];

            for (int i = 1; i < similarities.length; i++) {
              if (similarities[i] > bestSimilarity) {
                bestSimilarity = similarities[i];
                bestIndex = i;
              }
            }

            // Use the best match
            recognition = Recognition(
              recognition.name,
              recognition.studentId,
              recognitionAttempts[bestIndex].embedding,
              bestSimilarity,
            );

            print(
              "Best similarity with registered face: ${(bestSimilarity * 100).toStringAsFixed(1)}%",
            );
          } else {
            print("All recognition attempts failed");
          }
        } else {
          print("No registered face found for student ID: $_studentId");
          // Fall back to general recognition
          recognition = recognizer.recognize(croppedFace, boundingBox);
        }
      } else {
        // No student ID, use normal recognition
        recognition = recognizer.recognize(croppedFace, boundingBox);
      }

      // Show the result dialog with proper information
      // recognition is always non-null at this point due to the way recognize() is implemented
      showRecognitionResultDialog(croppedBytes, recognition);

      // Usar el nuevo método de verificación dual para mayor seguridad
      if (_studentId != null &&
          _studentId!.isNotEmpty &&
          recognition.embedding != null) {
        // Verificar usando el método de comparación dual
        bool isVerified = await recognizer.verifyFaceWithDualComparison(
          recognition.embedding!,
          _studentId!,
          securityMargin:
              0.30, // Margen de seguridad aumentado para evitar falsos positivos
        );

        if (isVerified) {
          print("Face verified with dual comparison method");
          await _sendFaceVerificationToServer();
        } else {
          print("Face verification failed with dual comparison method");
          // Mostrar mensaje de error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Face verification failed. This does not appear to be your face. Please try again with your own face.",
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        // Método anterior como fallback con umbral equilibrado
        double threshold =
            (_studentId != null && _studentId!.isNotEmpty)
                ? 75.0
                : 80.0; // تعديل من 85.0/90.0 إلى 75.0/80.0
        double similarityPercentage = recognition.distance * 100;

        // If face is recognized successfully, send verification to server
        if (similarityPercentage >= threshold &&
            recognition.name.toLowerCase() != "unknown") {
          print(
            "Face verified with similarity: ${similarityPercentage.toStringAsFixed(1)}%",
          );
          await _sendFaceVerificationToServer();
        } else {
          print(
            "Face verification failed: similarity ${similarityPercentage.toStringAsFixed(1)}% is below threshold $threshold% or face is unknown",
          );
        }
      }
    } catch (e) {
      print("Error in cropAndRegisterFace: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error processing face: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
            margin: EdgeInsets.only(bottom: 100, left: 20, right: 20),
          ),
        );
      }
    }
  }

  // New helper method to enhance face images for better recognition
  img.Image _enhanceFaceImage(img.Image faceImage) {
    try {
      // Apply a series of enhancements to improve recognition
      img.Image enhanced = faceImage;

      // Adjust color properties to improve facial features
      enhanced = img.adjustColor(
        enhanced,
        contrast: 1.3, // Increase contrast by 30%
        brightness: 1.05, // Slight brightness increase
        saturation: 0.9, // Slightly reduce saturation for more natural look
      );

      return enhanced;
    } catch (e) {
      print("Error enhancing face image: $e");
      return faceImage; // Return original on error
    }
  }

  // Helper method to create slightly different image enhancements for multiple recognition attempts
  img.Image _applyRandomEnhancements(img.Image baseImage, int seedModifier) {
    try {
      // Use seedModifier to create deterministic variations
      double contrastMod = 1.2 + (seedModifier % 3) * 0.1; // 1.2, 1.3, 1.4
      double brightnessMod =
          1.0 + (seedModifier % 5) * 0.03; // 1.0, 1.03, 1.06, 1.09, 1.12

      img.Image enhanced = img.adjustColor(
        baseImage,
        contrast: contrastMod,
        brightness: brightnessMod,
        saturation: 0.9 + (seedModifier % 3) * 0.1, // 0.9, 1.0, 1.1
      );

      return enhanced;
    } catch (e) {
      print("Error applying random enhancements: $e");
      return baseImage; // Return original on error
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
          print('>>> Verifying attendance for Course ID: ${widget.courseId}');

          final attendanceResponse = await http.post(
            Uri.parse('${ApiService.baseUrl}/attendance/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'student_id': studentId,
              'course_id': widget.courseId,
              'face_verified': true,
              'location_verified': true, // Añadir verificación de ubicación
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

  // Método para limpiar todas las caras registradas
  Future<void> _clearAllFaces() async {
    try {
      await databaseHelper.clearAllFaces();
      await recognizer.loadRegisteredFaces();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All registered faces have been deleted"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error clearing faces: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error clearing faces: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Remove rotation function (modifies image on file)
  removeRotation(File? inputImage) async {
    if (inputImage != null && inputImage.existsSync()) {
      try {
        final img.Image? capturedImage = img.decodeImage(
          await inputImage.readAsBytes(),
        );
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

  // Show recognition result dialog with improved verification
  void showRecognitionResultDialog(
    Uint8List faceImage,
    Recognition recognition,
  ) {
    // Calculate similarity percentage correctly
    double similarityPercentage = recognition.distance * 100;

    // Check if the distance value is valid
    if (similarityPercentage > 100 ||
        !similarityPercentage.isFinite ||
        similarityPercentage < 0) {
      print("Invalid similarity percentage: ${recognition.distance}");
      similarityPercentage = 0.0; // Reset to 0% if invalid
    }

    // تعديل الحد الأدنى للتشابه ليكون أكثر مرونة
    // If we have a specific student ID, we can use a lower threshold since we're verifying identity
    // If no student ID, we need a higher threshold for general recognition
    double threshold =
        (_studentId != null && _studentId!.isNotEmpty)
            ? 60.0
            : 65.0; // تخفيض من 75.0/80.0 إلى 60.0/65.0
    bool isValidSimilarity = similarityPercentage >= threshold;

    // تحقق إضافي: إذا كان الاسم "Unknown" أو "unknown"، فهذا يعني أن الوجه غير معروف
    bool isUnknownFace = recognition.name.toLowerCase() == "unknown";

    // إذا كان الوجه غير معروف، نعتبره غير صالح حتى لو كانت نسبة التشابه عالية
    if (isUnknownFace) {
      isValidSimilarity = false;
    }

    // تحقق إضافي: إذا كانت نسبة التشابه أقل من 75%، نعتبر الوجه غير معروف
    if (similarityPercentage < 75.0) {
      isUnknownFace = true;
      isValidSimilarity = false;
    }

    // Get student ID for display
    String displayStudentId = _studentId ?? "unknown";

    // Debug logging
    print(
      'Recognition similarity: ${similarityPercentage.toStringAsFixed(1)}%',
    );
    print('Threshold used: $threshold%');
    print('Valid recognition: $isValidSimilarity');
    print('Student ID: $displayStudentId');
    print('Recognized name: ${recognition.name}');
    print('Is unknown face: $isUnknownFace');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Recognition Result',
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    faceImage,
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isValidSimilarity
                      ? 'Face verified successfully!'
                      : isUnknownFace
                      ? 'Unrecognized Face!'
                      : 'Face verification failed!',
                  style: TextStyle(
                    color: isValidSimilarity ? Colors.green : Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  isValidSimilarity
                      ? 'Match rate: ${similarityPercentage.toStringAsFixed(1)}%'
                      : isUnknownFace
                      ? 'This face is not registered in the system. Please register first.'
                      : 'Low match rate: ${similarityPercentage.toStringAsFixed(1)}%\nThis does not appear to be your face. Please try again with your own face.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isValidSimilarity ? Colors.green : Colors.red,
                  ),
                ),
                // فقط إذا كان الوجه معروف وصالح، نعرض الاسم
                if (isValidSimilarity && !isUnknownFace) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Recognized: ${recognition.name}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Only return success if face verification is valid
                  if (isValidSimilarity) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: isValidSimilarity ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isValidSimilarity)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => RegistrationScreen(
                              studentData: widget.studentData,
                              studentId: _studentId,
                            ),
                      ),
                    );
                  },
                  child: const Text('Register'),
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
      builder:
          (ctx) => AlertDialog(
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
                            content: Text(
                              "No facial data available. Please try again.",
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      recognizer.registerFaceInDB(
                        textEditingController.text,
                        recognition
                            .embedding!, // Usar el operador ! para indicar que no es null
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
      appBar: AppBar(
        title: const Text(
          "Face Recognition",
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
        backgroundColor: ColorsManager.darkBlueColor1,
        leading: BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text("Clear Face Database"),
                      content: Text(
                        "Are you sure you want to delete all registered faces? This action cannot be undone.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            // Cerrar el diálogo inmediatamente
                            Navigator.pop(context);
                            // Luego realizar las operaciones asíncronas
                            _clearAllFaces();
                          },
                          child: Text(
                            "Delete All",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(height: 10.sp),
          Text(
            'Take photo of your face',
            style: TextStyle(
              fontSize: 24,
              color: ColorsManager.darkBlueColor1,
              fontWeight: FontWeight.bold,
            ),
          ),
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
          AppButton(
            buttonText: 'Capture',
            onPressed: () {
              _imgFromCamera();
            },
          ),
          SizedBox(height: 20.sp),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Text(
              faces.isEmpty ? 'No face detected' : 'Face detected successfully',
              style: TextStyle(
                color: faces.isEmpty ? Colors.red : Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
    Paint p =
        Paint()
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
