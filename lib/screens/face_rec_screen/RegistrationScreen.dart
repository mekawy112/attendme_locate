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
        return recognition.embedding;
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
  List<double> _calculateAverageEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) {
      throw Exception('No embeddings provided');
    }
    
    int embeddingLength = embeddings.first.length;
    List<double> averageEmbedding = List<double>.filled(embeddingLength, 0.0);
    
    // Sumar todos los embeddings
    for (int i = 0; i < embeddings.length; i++) {
      for (int j = 0; j < embeddingLength; j++) {
        averageEmbedding[j] += embeddings[i][j];
      }
    }
    
    // Calcular el promedio
    for (int i = 0; i < embeddingLength; i++) {
      averageEmbedding[i] /= embeddings.length;
    }
    
    // Normalizar el vector (convertirlo a vector unitario)
    double magnitude = 0.0;
    for (int i = 0; i < embeddingLength; i++) {
      magnitude += averageEmbedding[i] * averageEmbedding[i];
    }
    
    magnitude = math.sqrt(magnitude);
    
    // Evitar divisin por cero
    if (magnitude > 0) {
      for (int i = 0; i < embeddingLength; i++) {
        averageEmbedding[i] /= magnitude;
      }
    }
    
    return averageEmbedding;
  }

  // دالة لحساب التشابه بين اثنين من الـ embeddings
  double _calculateSimilarity(List<double> embedding1, List<double> embedding2) {
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

  // التحقق من أن جميع الصور لنفس الشخص
  Future<bool> _areFacesMatching(List<List<double>> embeddingsList) async {
    if (embeddingsList.length < 2) return true;
    
    // تخفيف عتبة التشابه - يجب أن تكون النسبة أعلى من 20% للقبول
    const double similarityThreshold = 20.0;
    
    // مقارنة كل زوج من الوجوه
    for (int i = 0; i < embeddingsList.length - 1; i++) {
      for (int j = i + 1; j < embeddingsList.length; j++) {
        double similarity = _calculateSimilarity(embeddingsList[i], embeddingsList[j]);
        print('Similarity between faces $i and $j: $similarity%');
        
        if (similarity < similarityThreshold) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("التحقق من الهوية: الصور ليست لنفس الشخص (نسبة التطابق: ${similarity.toStringAsFixed(1)}%). يرجى التقاط صور لنفس الشخص فقط"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 5),
            ),
          );
          return false;
        }
      }
    }
    return true;
  }

  // التحقق من أن الصور لا تنتمي لطالب مسجل مسبقاً
  Future<bool> _verifyNotRegistered(List<List<double>> embeddingsList) async {
    try {
      // حساب متوسط الـ embedding للصور الملتقطة
      List<double> averageEmbedding = _calculateAverageEmbedding(embeddingsList);
      
      // جلب جميع الوجوه المسجلة من قاعدة البيانات
      List<Map<String, dynamic>> registeredFaces = await databaseHelper.getAllFaces();
      
      // عتبة التشابه للتحقق من عدم التطابق مع وجوه مسجلة - يجب أن تكون النسبة أقل من 85% للقبول
      const double registeredThreshold = 85.0;
      
      for (var face in registeredFaces) {
        // تحويل النص JSON إلى قائمة
        List<dynamic> embeddingJson = jsonDecode(face['embedding']);
        List<double> registeredEmbedding = embeddingJson.map((e) => (e as num).toDouble()).toList();
        
        double similarity = _calculateSimilarity(averageEmbedding, registeredEmbedding);
        print('Similarity with registered face ${face['name']}: $similarity%');
        
        if (similarity > registeredThreshold) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("التحقق من الهوية: الصور تنتمي لطالب مسجل مسبقاً (${face['name']}) بنسبة تطابق ${similarity.toStringAsFixed(1)}%. يرجى استخدام صورك الشخصية فقط"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 5),
            ),
          );
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error in verification: $e');
      return false;
    }
  }

  // التحقق من وجود وجه مسجل مسبقًا للطالب
  Future<bool> _checkExistingFace() async {
    // تأكد من وجود معرف للطالب
    if (widget.studentId == null || widget.studentId!.isEmpty) {
      return false;
    }
    
    // استخدام DatabaseHelper للتحقق من وجود الطالب
    final dbHelper = DatabaseHelper();
    await dbHelper.init();
    
    // Consulta personalizada para verificar la existencia del estudiante
    final result = await dbHelper.query(
      DatabaseHelper.table,
      where: '${DatabaseHelper.columnStudentId} = ?',
      whereArgs: [widget.studentId],
    );
    
    return result.isNotEmpty;
  }

  // دالة تسجيل الوجوه: معالجة 3 صور، حساب المتوسط وتسجيلها مع اسم الطالب
  Future<void> registerFace() async {
    if (capturedImages.length != 3) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
      
      // Process each image to get embeddings
      for (var image in capturedImages) {
        final embedding = await processImageForEmbedding(image);
        if (embedding != null) {
          embeddings.add(embedding);
        }
      }

      if (embeddings.length != 3) {
        throw Exception('Failed to process all images');
      }

      // Calculate average embedding
      List<double> averageEmbedding = List.filled(embeddings[0].length, 0);
      for (var embedding in embeddings) {
        for (int i = 0; i < embedding.length; i++) {
          averageEmbedding[i] += embedding[i] / 3;
        }
      }

      // Create Recognition object with average embedding
      Recognition recognition = Recognition(
        widget.studentData?['name'] ?? 'Unknown',
        widget.studentId ?? '',
        averageEmbedding,
        0.0  // Initial distance
      );

      // Save to database
      await databaseHelper.insertFace(
        widget.studentId ?? '',
        averageEmbedding,
        widget.studentData?['name'] ?? 'Unknown'
      );

      // Reload faces in recognizer
      await recognizer.loadRegisteredFaces();

      setState(() {
        isProcessing = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face registered successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context, true);  // Return true to indicate successful registration

    } catch (e) {
      setState(() {
        isProcessing = false;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: const Text("Face Registration",style: TextStyle(
        fontSize: 20,
        color: Colors.white
      ),), backgroundColor: ColorsManager.darkBlueColor1,
      leading: BackButton(
        color: Colors.white,
      ),),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(
                height: 20.sp,
              ),
              Text('Tap and take 3 photos of yours face',style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: ColorsManager.darkBlueColor1

              ),),
              SizedBox(height: 15.sp,),
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
                      margin: EdgeInsets.only(left: 15.w, bottom: 10.h, top: 10.h),
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
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
                          )
                        ],
                      ),
                      child: SvgPicture.asset(
                        'assets/svgs/logo.svg',
                      ),
                    ),
                    onTap: capturedImages.length < 3 ? _pickImageFromCamera : null,
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
                    AppTextFormField(label: 'Full Name',controller: nameController,
                    hintText: 'Enter your name',),
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
                        backgroundColor: ColorsManager.darkBlueColor1
                      ),
                      onPressed: registerFace,
                      child: const Text("Register Face", style: TextStyle(
                        fontSize: 18,
                        color: Colors.white
                      ),),
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
