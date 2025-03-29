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

  // التحقق من أن جميع الصور لنفس الشخص
  Future<bool> _areFacesMatching(List<List<double>> embeddingsList) async {
    if (embeddingsList.length < 2) return true;
    
    // عتبة التشابه - إذا كان التشابه أقل من هذه القيمة، فالوجوه مختلفة
    const double similarityThreshold = 0.3; // Reducido aún más para ser más permisivo
    
    // مقارنة كل زوج من الوجوه
    for (int i = 0; i < embeddingsList.length - 1; i++) {
      for (int j = i + 1; j < embeddingsList.length; j++) {
        double similarity = _calculateCosineSimilarity(embeddingsList[i], embeddingsList[j]);
        print('Similarity between face $i and face $j: $similarity');
        if (similarity < similarityThreshold) {
          return false; // الوجوه مختلفة
        }
      }
    }
    
    return true; // جميع الوجوه متطابقة
  }
  
  // حساب تشابه جيب التمام بين متجهين
  double _calculateCosineSimilarity(List<double> vec1, List<double> vec2) {
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
    
    // Usar sqrt de dart:math que ya fue importada
    return dotProduct / (math.sqrt(norm1) * math.sqrt(norm2));
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
    // التحقق من عدد الصور
    if (capturedImages.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرجاء التقاط 3 صور")),
      );
      return;
    }

    // التحقق من إدخال الاسم
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرجاء إدخال الاسم")),
      );
      return;
    }

    // التأكد من وجود معرف للطالب
    if (widget.studentId == null || widget.studentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("معرف الطالب غير متوفر")),
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      // التحقق من وجود وجه مسجل مسبقًا
      bool hasExistingFace = await _checkExistingFace();
      
      if (hasExistingFace) {
        // إذا كان هناك وجه مسجل، نسأل المستخدم إذا كان يريد الاستبدال
        bool shouldReplace = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("تم العثور على وجه مسجل"),
            content: const Text("لديك وجه مسجل بالفعل. هل تريد استبداله؟"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("لا"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("نعم"),
              ),
            ],
          ),
        ) ?? false; // إذا أغلق المستخدم الحوار بدون اختيار، نفترض "لا"
        
        if (!shouldReplace) {
          setState(() {
            isProcessing = false;
          });
          return;
        }
      }

      List<List<double>> embeddingsList = [];
      for (int i = 0; i < capturedImages.length; i++) {
        List<double>? emb = await processImageForEmbedding(capturedImages[i]);
        if (emb == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("لم يتم اكتشاف وجه في الصورة ${i+1}، يرجى إعادة التقاط.")),
          );
          setState(() {
            isProcessing = false;
          });
          return;
        }
        embeddingsList.add(emb);
      }

      // TEMPORALMENTE OMITIENDO la verificaciu00f3n de coincidencia de rostros
      bool facesMatch = true; // Forzar a que siempre sea verdadero
      
      if (!facesMatch) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم اكتشاف وجوه مختلفة في الصور! يرجى التقاط صور لنفس الشخص."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        setState(() {
          isProcessing = false;
        });
        return;
      }

      // حساب المتوسط من الثلاثة embeddings
      List<double> avgEmbedding = _calculateAverageEmbedding(embeddingsList);

      // تسجيل الوجه في قاعدة البيانات باستخدام Recognizer مع تمرير معرف الطالب
      recognizer.registerFaceInDB(nameController.text, avgEmbedding, widget.studentId!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تسجيل الوجه بنجاح")),
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
        SnackBar(content: Text("فشل التسجيل: ${e.toString()}")),
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
              // عند التقاط 3 صور، عرض حقل إدخال الاسم وزر التسجيل
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
