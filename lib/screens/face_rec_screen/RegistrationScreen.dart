import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import 'ML/Recognition.dart';
import 'ML/Recognizer.dart';


class RegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? studentData;
  final String? studentId;

  const RegistrationScreen({
    Key? key, 
    this.studentData,
    this.studentId,
  }) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late ImagePicker imagePicker;
  // قائمة لتخزين الصور الملتقطة
  List<File> capturedImages = [];
  TextEditingController nameController = TextEditingController();

  late FaceDetector faceDetector;
  late Recognizer recognizer;

  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();

    // تهيئة كاشف الوجوه باستخدام خيارات دقيقة
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    );
    faceDetector = FaceDetector(options: options);

    // تهيئة Recognizer الذي يحمل الموديل وعمليات التعرف
    recognizer = Recognizer();
  }

  @override
  void dispose() {
    faceDetector.close(); // إغلاق كاشف الوجوه لتفادي تسرب الذاكرة
    nameController.dispose();
    super.dispose();
  }

  // دالة التقاط صورة من الكاميرا
  Future<void> _pickImageFromCamera() async {
    if (capturedImages.length >= 3) return;
    try {
      XFile? pickedFile = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // تحسين جودة الصورة
        maxWidth: 1000,   // تحديد العرض الأقصى
        maxHeight: 1000,  // تحديد الارتفاع الأقصى
      );
      if (pickedFile != null) {
        setState(() {
          capturedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      print('Error picking image from camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to capture image from camera")),
      );
    }
  }

  // دالة التقاط صورة من المعرض
  Future<void> _pickImageFromGallery() async {
    if (capturedImages.length >= 3) return;
    try {
      XFile? pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // تحسين جودة الصورة
        maxWidth: 1000,   // تحديد العرض الأقصى
        maxHeight: 1000,  // تحديد الارتفاع الأقصى
      );
      if (pickedFile != null) {
        setState(() {
          capturedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to pick image from gallery")),
      );
    }
  }

  // دالة مساعدة لمعالجة صورة واحدة:
  // تصحيح اتجاه الصورة، اكتشاف الوجه، قصه واستخراج الـ embedding
  // دالة مساعدة لمعالجة صورة واحدة:
  Future<List<double>?> processImageForEmbedding(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        print('Failed to decode image');
        return null;
      }

      // تصحيح اتجاه الصورة
      img.Image orientedImage = img.bakeOrientation(originalImage);

      // تحسين حجم الصورة للمعالجة
      if (orientedImage.width > 1000 || orientedImage.height > 1000) {
        orientedImage = img.copyResize(
          orientedImage,
          width: orientedImage.width > orientedImage.height
              ? 1000
              : (1000 * orientedImage.width ~/ orientedImage.height),
          height: orientedImage.height > orientedImage.width
              ? 1000
              : (1000 * orientedImage.height ~/ orientedImage.width),
        );
      }

      // حفظ الصورة المؤقتة لمعالجتها بواسطة ML Kit
      final tempDir = Directory.systemTemp;
      final tempPath = '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = await File(tempPath).writeAsBytes(img.encodeJpg(orientedImage));
      final inputImage = InputImage.fromFile(tempFile);

      try {
        // الكشف عن الوجوه باستخدام ML Kit
        List<Face> faces = await faceDetector.processImage(inputImage);
        if (faces.isEmpty) {
          print('No faces detected in the image');
          return null;
        }

        // استخدام أول وجه مكتشف
        Face face = faces.first;
        Rect boundingBox = face.boundingBox;

        // التأكد من أن مربع الوجه ضمن حدود الصورة
        int left = boundingBox.left < 0 ? 0 : boundingBox.left.toInt();
        int top = boundingBox.top < 0 ? 0 : boundingBox.top.toInt();
        int right = boundingBox.right > orientedImage.width ? orientedImage.width - 1 : boundingBox.right.toInt();
        int bottom = boundingBox.bottom > orientedImage.height ? orientedImage.height - 1 : boundingBox.bottom.toInt();
        int width = right - left;
        int height = bottom - top;

        if (width <= 0 || height <= 0) {
          print('Invalid face bounding box dimensions: $width x $height');
          return null;
        }

        // قص الوجه من الصورة - تصحيح استدعاء الدالة
        img.Image croppedFace = img.copyCrop(
            orientedImage,
            x: left,
            y: top,
            width: width,
            height: height
        );

        // تحسين حجم الوجه المقصوص للتعرف
        croppedFace = img.copyResize(croppedFace, width: 112, height: 112);

        // استخراج الـ embedding باستخدام Recognizer
        Recognition recognition = recognizer.recognize(croppedFace, boundingBox);
        return recognition.embeddings;
      } catch (e) {
        print('Error in face detection or recognition: $e');
        return null;
      } finally {
        // تنظيف الملف المؤقت
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          print('Error deleting temporary file: $e');
        }
      }
    } catch (e) {
      print('Error in image processing: $e');
      return null;
    }
  }

  // دالة لحساب المتوسط بين عدة embeddings
  List<double> averageEmbedding(List<List<double>> embeddingsList) {
    int len = embeddingsList[0].length;
    List<double> avg = List.filled(len, 0.0);
    for (var emb in embeddingsList) {
      for (int i = 0; i < len; i++) {
        avg[i] += emb[i];
      }
    }
    for (int i = 0; i < len; i++) {
      avg[i] /= embeddingsList.length;
    }
    return avg;
  }

  // دالة تسجيل الوجوه: معالجة 3 صور، حساب المتوسط وتسجيلها مع اسم الطالب
  Future<void> registerFace() async {
    if (capturedImages.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please capture 3 images")),
      );
      return;
    }

    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name")),
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      List<List<double>> embeddingsList = [];
      for (int i = 0; i < capturedImages.length; i++) {
        List<double>? emb = await processImageForEmbedding(capturedImages[i]);
        if (emb == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Face not detected in image ${i+1}, please retake.")),
          );
          setState(() {
            isProcessing = false;
          });
          return;
        }
        embeddingsList.add(emb);
      }

      // حساب المتوسط من الثلاثة embeddings
      List<double> avgEmbedding = averageEmbedding(embeddingsList);

      // تسجيل الوجه في قاعدة البيانات باستخدام Recognizer
      // إزالة كلمة await إذا كانت الدالة لا تعيد Future
      recognizer.registerFaceInDB(nameController.text, avgEmbedding);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Face Registered Successfully")),
      );

      // إعادة تهيئة المتغيرات للتسجيل الجديد
      setState(() {
        capturedImages.clear();
        nameController.clear();
        isProcessing = false;
      });
    } catch (e) {
      print('Error during face registration: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: ${e.toString()}")),
      );
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: const Text("Face Registration")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // عرض الصور الملتقطة كتصغير (thumbnails)
              if (capturedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: capturedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Stack(
                          children: [
                            Image.file(
                              capturedImages[index],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                            // زر حذف الصورة في حال أردت إعادة التقاطها
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    capturedImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  color: Colors.red,
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              // أزرار التقاط الصور من الكاميرا أو المعرض
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: capturedImages.length < 3 ? _pickImageFromCamera : null,
                    icon: const Icon(Icons.camera),
                    label: const Text("Camera"),
                  ),
                  ElevatedButton.icon(
                    onPressed: capturedImages.length < 3 ? _pickImageFromGallery : null,
                    icon: const Icon(Icons.photo),
                    label: const Text("Gallery"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // عند التقاط 3 صور، عرض حقل إدخال الاسم وزر التسجيل
              if (capturedImages.length == 3)
                Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Enter Student Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    isProcessing
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: registerFace,
                      child: const Text("Register Face"),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
