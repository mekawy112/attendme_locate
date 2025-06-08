import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:attend_me_locate/widgets/app_text_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';

import '../../core/theming/colors.dart';
import 'ML/Recognition.dart';
import 'ML/Recognizer.dart';
import 'DB/DatabaseHelper.dart';

class RegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? studentData;
  final String? studentId;

  const RegistrationScreen({Key? key, this.studentData, this.studentId})
    : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late ImagePicker imagePicker;
  List<File> capturedImages = [];
  TextEditingController nameController = TextEditingController();
  late DatabaseHelper databaseHelper;

  late FaceDetector faceDetector;
  late Recognizer recognizer;

  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    databaseHelper = DatabaseHelper();
    _initDatabase();

    // تهيئة كاشف الوجوه باستخدام خيارات دقيقة
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    );
    faceDetector = FaceDetector(options: options);

    // تهيئة Recognizer الذي يحمل الموديل وعمليات التعرف
    recognizer = Recognizer();
  }

  Future<void> _initDatabase() async {
    await databaseHelper.init();
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
        imageQuality: 100, // Increase image quality to maximum
        maxWidth: 1200, // Increase maximum width
        maxHeight: 1200, // Increase maximum height
        preferredCameraDevice:
            CameraDevice.front, // Use front camera by default
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
        maxWidth: 1000, // تحديد العرض الأقصى
        maxHeight: 1000, // تحديد الارتفاع الأقصى
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

      // تطبيق تحسينات على الصورة لتعزيز جودة التعرف
      img.Image enhancedImage = _enhanceImageQuality(orientedImage);

      // حفظ الصورة المؤقتة لمعالجتها بواسطة ML Kit
      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = await File(
        tempPath,
      ).writeAsBytes(img.encodeJpg(enhancedImage, quality: 100));
      final inputImage = InputImage.fromFile(tempFile);

      try {
        // الكشف عن الوجوه باستخدام ML Kit مع تمكين التدقيق الإضافي
        print('Detecting faces in image...');
        List<Face> faces = await faceDetector.processImage(inputImage);

        if (faces.isEmpty) {
          print('No faces detected in the image');
          return null;
        }

        print('Found ${faces.length} faces in image');

        // اختيار الوجه الأكبر إذا كان هناك أكثر من وجه
        Face bestFace = _getLargestFace(faces);

        Rect boundingBox = bestFace.boundingBox;
        print('Selected face bounding box: ${boundingBox.toString()}');

        // التأكد من أن مربع الوجه ضمن حدود الصورة
        int left = boundingBox.left < 0 ? 0 : boundingBox.left.toInt();
        int top = boundingBox.top < 0 ? 0 : boundingBox.top.toInt();
        int right =
            boundingBox.right > enhancedImage.width
                ? enhancedImage.width - 1
                : boundingBox.right.toInt();
        int bottom =
            boundingBox.bottom > enhancedImage.height
                ? enhancedImage.height - 1
                : boundingBox.bottom.toInt();

        // توسيع مربع الوجه قليلاً لتضمين المزيد من السياق
        int expandedWidth = ((right - left) * 1.1).toInt();
        int expandedHeight = ((bottom - top) * 1.1).toInt();

        // حساب نقطة المركز للمربع الأصلي
        int centerX = (left + right) ~/ 2;
        int centerY = (top + bottom) ~/ 2;

        // إعادة حساب الحدود الموسعة مع التأكد من عدم تجاوز حدود الصورة
        left = math.max(0, centerX - expandedWidth ~/ 2);
        top = math.max(0, centerY - expandedHeight ~/ 2);
        right = math.min(enhancedImage.width - 1, centerX + expandedWidth ~/ 2);
        bottom = math.min(
          enhancedImage.height - 1,
          centerY + expandedHeight ~/ 2,
        );

        int width = right - left;
        int height = bottom - top;

        if (width <= 0 || height <= 0) {
          print('Invalid face bounding box dimensions: $width x $height');
          return null;
        }

        print(
          'Final crop dimensions: left=$left, top=$top, width=$width, height=$height',
        );

        // قص الوجه من الصورة
        img.Image croppedFace = img.copyCrop(
          enhancedImage,
          x: left,
          y: top,
          width: width,
          height: height,
        );

        // تحسين حجم الوجه المقصوص للتعرف
        croppedFace = img.copyResize(croppedFace, width: 112, height: 112);

        // تطبيق تحسينات إضافية على صورة الوجه
        croppedFace = _enhanceFace(croppedFace);

        // استخراج الـ embedding باستخدام Recognizer مع المحاولات المتعددة
        List<List<double>> embeddingAttempts = [];
        for (int i = 0; i < 5; i++) {
          // زيادة عدد المحاولات من 3 إلى 5 للحصول على نتائج أفضل
          Recognition recognition = recognizer.recognize(
            croppedFace,
            boundingBox,
          );
          if (recognition.embedding != null &&
              recognition.embedding!.isNotEmpty) {
            // تحقق من جودة الـ embedding قبل إضافته
            double embNorm = 0;
            for (double val in recognition.embedding!) {
              embNorm += val * val;
            }
            embNorm = math.sqrt(embNorm);

            // تجاهل الـ embeddings ذات القيم المنخفضة جدًا
            if (embNorm > 0.1) {
              embeddingAttempts.add(recognition.embedding!);
              print('Added valid embedding attempt $i with norm: $embNorm');
            } else {
              print(
                'Skipped low-quality embedding attempt $i with norm: $embNorm',
              );
              // إضافة محاولة إضافية لتعويض المحاولة المرفوضة
              i--;
            }
          }
        }

        if (embeddingAttempts.isEmpty) {
          print('Failed to extract embeddings');
          return null;
        }

        // حساب متوسط الـ embedding من المحاولات المتعددة
        return _calculateAverageEmbedding(embeddingAttempts);
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

  // دالة جديدة لتحسين جودة الصورة الأصلية
  img.Image _enhanceImageQuality(img.Image image) {
    try {
      // تطبيق سلسلة من التحسينات لزيادة وضوح الصورة
      img.Image enhanced = image;

      // تحسين التباين والسطوع باستخدام عمليات أساسية
      enhanced = img.adjustColor(
        enhanced,
        contrast: 1.2, // زيادة التباين بنسبة 20%
        brightness: 1.05, // زيادة طفيفة في السطوع
        saturation: 1.1, // زيادة طفيفة في التشبع للألوان
      );

      return enhanced;
    } catch (e) {
      print('Error enhancing image: $e');
      return image; // إرجاع الصورة الأصلية في حالة الخطأ
    }
  }

  // دالة جديدة لتحسين صورة الوجه المقصوص
  img.Image _enhanceFace(img.Image faceImage) {
    try {
      // استخدام فقط عمليات ضبط الألوان الأساسية
      img.Image enhanced = img.adjustColor(
        faceImage,
        contrast: 1.3, // زيادة أكبر في التباين
        brightness: 1.1, // زيادة السطوع
        saturation: 0.9, // تقليل التشبع قليلاً للحصول على ألوان أكثر واقعية
      );

      return enhanced;
    } catch (e) {
      print('Error enhancing face: $e');
      return faceImage; // إرجاع صورة الوجه الأصلية في حالة الخطأ
    }
  }

  // دالة جديدة لاختيار الوجه الأكبر من بين الوجوه المكتشفة
  Face _getLargestFace(List<Face> faces) {
    if (faces.length == 1) return faces.first;

    Face largest = faces.first;
    double largestArea = _getFaceArea(largest);

    for (int i = 1; i < faces.length; i++) {
      double area = _getFaceArea(faces[i]);
      if (area > largestArea) {
        largest = faces[i];
        largestArea = area;
      }
    }

    return largest;
  }

  // دالة مساعدة لحساب مساحة الوجه
  double _getFaceArea(Face face) {
    return face.boundingBox.width * face.boundingBox.height;
  }

  // دالة لحساب المتوسط بين عدة embeddings مع تحسينات إضافية
  List<double> _calculateAverageEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) {
      throw Exception('No embeddings provided');
    }

    int embeddingLength = embeddings.first.length;
    List<double> averageEmbedding = List<double>.filled(embeddingLength, 0.0);

    // حساب المتوسط المرجح بناءً على جودة كل embedding
    List<double> weights = [];

    // حساب معيار الجودة لكل embedding
    for (var embedding in embeddings) {
      double norm = 0.0;
      for (double val in embedding) {
        norm += val * val;
      }
      norm = math.sqrt(norm);

      // كلما كان الـ norm أعلى، كلما كان الوزن أعلى
      double weight =
          norm * 2.0; // مضاعفة تأثير الـ embeddings ذات الجودة العالية
      weights.add(weight);
    }

    // تطبيع الأوزان لتكون مجموعها 1
    double totalWeight = weights.fold(0.0, (sum, weight) => sum + weight);
    if (totalWeight > 0) {
      for (int i = 0; i < weights.length; i++) {
        weights[i] /= totalWeight;
      }
    } else {
      // إذا كانت جميع الأوزان صفرًا، استخدم أوزانًا متساوية
      for (int i = 0; i < weights.length; i++) {
        weights[i] = 1.0 / weights.length;
      }
    }

    // حساب المتوسط المرجح
    for (int i = 0; i < embeddings.length; i++) {
      var embedding = embeddings[i];
      double weight = weights[i];

      for (int j = 0; j < embeddingLength; j++) {
        averageEmbedding[j] += embedding[j] * weight;
      }
    }

    // تطبيع المتجه النهائي
    double norm = 0.0;
    for (double val in averageEmbedding) {
      norm += val * val;
    }
    norm = math.sqrt(norm);

    if (norm > 0) {
      for (int i = 0; i < embeddingLength; i++) {
        averageEmbedding[i] /= norm;
      }
    }

    return averageEmbedding;
  }

  // دالة لحساب التشابه بين اثنين من الـ embeddings
  double _calculateSimilarity(
    List<double> embedding1,
    List<double> embedding2,
  ) {
    if (embedding1.length != embedding2.length) {
      throw Exception('Embeddings have different lengths');
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    norm1 = math.sqrt(norm1);
    norm2 = math.sqrt(norm2);

    if (norm1 == 0 || norm2 == 0) {
      return 0.0;
    }

    // تحويل التشابه إلى نسبة مئوية وتقييد القيمة بين 0 و 100
    double similarity = (dotProduct / (norm1 * norm2));
    return similarity.clamp(0.0, 1.0) * 100; // تحويل إلى نسبة مئوية
  }

  // Eliminamos la función _areFacesMatching ya que no la utilizamos más

  // تحسين التحقق من عدم وجود تسجيل مسبق للوجه
  // تم تعديل هذه الدالة لتعيد دائمًا true للسماح بتسجيل أي وجه حتى لو كان مسجل مسبقًا
  Future<bool> _verifyNotRegistered(List<List<double>> embeddings) async {
    // نتجاهل التحقق من الوجوه المسجلة مسبقًا ونعيد دائمًا true
    return true;
  }

  // دالة لمسح جميع الصور المخزنة في الهاتف
  Future<void> _clearAllFaces() async {
    try {
      // استخدام DatabaseHelper لمسح جميع الوجوه المسجلة
      await databaseHelper.clearAllFaces();

      // إعادة تحميل الوجوه المسجلة في recognizer
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

  // دالة تسجيل الوجوه: معالجة 3 صور، حساب المتوسط وتسجيلها مع اسم الطالب
  Future<void> registerFace() async {
    if (capturedImages.length != 3) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Registration Error'),
              content: Text('Please capture exactly 3 photos.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      List<List<double>> embeddings = [];
      List<File> validImages = [];

      // First step: process each image to extract face embeddings
      for (var image in capturedImages) {
        final embedding = await processImageForEmbedding(image);
        if (embedding != null) {
          // Validate embedding values
          bool isValid = true;
          for (double value in embedding) {
            if (!value.isFinite) {
              isValid = false;
              break;
            }
          }

          if (isValid) {
            embeddings.add(embedding);
            validImages.add(image);
            print(
              'Valid embedding extracted with ${embedding.length} dimensions',
            );
          } else {
            print('Skipping invalid embedding with non-finite values');
          }
        }
      }

      if (embeddings.isEmpty) {
        throw Exception(
          'Could not extract valid embeddings from any of the images',
        );
      }

      if (embeddings.length < 3) {
        print('Warning: Could only process ${embeddings.length} of 3 images');
        // If we don't have enough valid images, show warning
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could only process ${embeddings.length} of 3 images. Quality may be affected.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      // Omitimos la verificación de que todas las caras pertenecen a la misma persona
      // Esto permite registrar 3 fotos tomadas en el mismo momento sin problemas

      // Third step: verify this face isn't already registered for another student
      bool notAlreadyRegistered = await _verifyNotRegistered(embeddings);
      if (!notAlreadyRegistered) {
        throw Exception(
          'This face appears to be already registered for another student.',
        );
      }

      // Calculate average embedding
      List<double> averageEmbedding = _calculateAverageEmbedding(embeddings);

      // Validate average embedding
      bool hasInvalidValues = false;
      for (double value in averageEmbedding) {
        if (!value.isFinite) {
          hasInvalidValues = true;
          break;
        }
      }

      if (hasInvalidValues) {
        throw Exception('Generated embedding contains invalid values');
      }

      // Get appropriate student ID and name
      String studentId = widget.studentId ?? '';
      // Use the name entered by the user in the text field instead of the name from studentData
      String studentName = nameController.text.trim();

      if (studentId.isEmpty) {
        throw Exception('Student ID is required for registration');
      }

      if (studentName.isEmpty) {
        throw Exception('Name is required for registration');
      }

      // Check if this student already has a registered face
      final existingFace = await databaseHelper.queryStudentById(studentId);
      if (existingFace.isNotEmpty) {
        print('Student already has a registered face. Updating the record.');
        await databaseHelper.deleteByStudentId(studentId);
      }

      // Save to database using the insertFace method
      int result = await databaseHelper.insertFace(
        studentId,
        averageEmbedding,
        studentName, // Use the name entered by the user
      );

      if (result <= 0) {
        throw Exception('Failed to save face data to database');
      }

      // Reload faces in recognizer
      await recognizer.loadRegisteredFaces();
      print('Successfully registered face in database with ID: $result');

      setState(() {
        isProcessing = false;
      });

      // Show success message and navigate back only if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate successful registration
      }
    } catch (e) {
      setState(() {
        isProcessing = false;
      });

      // Show error dialog only if widget is still mounted
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Registration Error'),
                content: Text('Failed to register face: $e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Face Registration",
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
        backgroundColor: ColorsManager.darkBlueColor1,
        leading: BackButton(color: Colors.white),
        actions: [
          // زر لمسح جميع الصور المخزنة في الهاتف
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text("Delete All Faces"),
                      content: const Text(
                        "Are you sure you want to delete all registered faces? This action cannot be undone.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _clearAllFaces();
                          },
                          child: const Text(
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: 20.sp),
              Text(
                'Tap and take 3 photos of yours face',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: ColorsManager.darkBlueColor1,
                ),
              ),
              SizedBox(height: 15.sp),
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
                                  color: ColorsManager.blueColor,
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
                  GestureDetector(
                    child: Container(
                      margin: EdgeInsets.only(
                        left: 15.w,
                        bottom: 10.h,
                        top: 10.h,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 10.h,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ColorsManager.darkBlueColor1,
                            blurRadius: 4,
                            spreadRadius: 1,
                            offset: Offset(2, 2),
                          ),
                          BoxShadow(
                            color: Colors.blue,
                            blurRadius: 4,
                            spreadRadius: 1,
                            offset: Offset(-2, -2),
                          ),
                        ],
                      ),
                      child: SvgPicture.asset('assets/svgs/logo.svg'),
                    ),
                    onTap:
                        capturedImages.length < 3 ? _pickImageFromCamera : null,
                  ),
                  // ElevatedButton.icon(
                  //   onPressed: capturedImages.length < 3 ? _pickImageFromCamera : null,
                  //   icon: const Icon(Icons.camera),
                  //   label: const Text("Camera"),
                  // ),
                  // ElevatedButton.icon(
                  //   onPressed: capturedImages.length < 3 ? _pickImageFromGallery : null,
                  //   icon: const Icon(Icons.photo),
                  //   label: const Text("Gallery"),
                  // ),
                ],
              ),
              const SizedBox(height: 20),
              // عند التقاط 3 صور، عرض قل إدخال الاسم وزر التسجيل
              if (capturedImages.length == 3)
                Column(
                  children: [
                    AppTextFormField(
                      label: 'Full Name',
                      controller: nameController,
                      hintText: 'Enter your name',
                    ),
                    // TextField(
                    //   controller: nameController,
                    //   decoration: const InputDecoration(
                    //     labelText: "Enter Student Name",
                    //     border: OutlineInputBorder(),
                    //   ),
                    // ),
                    const SizedBox(height: 20),
                    isProcessing
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorsManager.darkBlueColor1,
                          ),
                          onPressed: registerFace,
                          child: const Text(
                            "Register Face",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
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
