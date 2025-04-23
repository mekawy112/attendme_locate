import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

// هذا مثال على كيفية دمج نموذج PyTorch مع Flutter
// في التطبيق الحقيقي، يمكنك استخدام مكتبة pytorch_mobile أو pytorch_flutter
// لتشغيل النموذج محليًا، أو استخدام خادم API كما هو موضح هنا

class FaceRecognitionScreen extends StatefulWidget {
  final String studentId;
  final String courseId;

  const FaceRecognitionScreen({
    Key? key,
    required this.studentId,
    required this.courseId,
  }) : super(key: key);

  @override
  _FaceRecognitionScreenState createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  late CameraController _cameraController;
  late List<CameraDescription> cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _resultMessage = "";
  bool _isVerified = false;
  double _similarity = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    
    // استخدام الكاميرا الأمامية
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    await _cameraController.initialize();
    
    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _resultMessage = "جاري التحقق...";
    });
    
    try {
      // التقاط صورة
      final XFile imageFile = await _cameraController.takePicture();
      
      // تحسين الصورة (اختياري)
      final File enhancedImage = await _enhanceImage(File(imageFile.path));
      
      // إرسال الصورة إلى الخادم للتحقق
      final result = await _verifyFaceWithServer(enhancedImage);
      
      setState(() {
        _isProcessing = false;
        _isVerified = result['verified'];
        _similarity = result['similarity'];
        
        if (_isVerified) {
          _resultMessage = "تم التحقق بنجاح! (${(_similarity * 100).toStringAsFixed(1)}%)";
          // إرسال تأكيد الحضور إلى الخادم
          _sendAttendanceConfirmation();
        } else {
          _resultMessage = "فشل التحقق. (${(_similarity * 100).toStringAsFixed(1)}%)";
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _resultMessage = "حدث خطأ: $e";
      });
    }
  }

  Future<File> _enhanceImage(File imageFile) async {
    // قراءة الصورة
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    
    if (image == null) return imageFile;
    
    // تحسين الصورة
    image = img.adjustColor(
      image,
      contrast: 1.3,  // زيادة التباين
      brightness: 1.05,  // زيادة السطوع قليلاً
      saturation: 0.9,  // تقليل التشبع قليلاً
    );
    
    // حفظ الصورة المحسنة
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/enhanced_image.jpg';
    final enhancedFile = File(tempPath);
    await enhancedFile.writeAsBytes(img.encodeJpg(image, quality: 90));
    
    return enhancedFile;
  }

  Future<Map<String, dynamic>> _verifyFaceWithServer(File imageFile) async {
    // تحويل الصورة إلى base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    
    // إرسال الطلب إلى الخادم
    final response = await http.post(
      Uri.parse('http://192.168.1.10:5000/attendance/verify-face'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_id': widget.studentId,
        'image': base64Image,
      }),
    );
    
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return {
        'verified': result['success'] == true,
        'similarity': result['similarity'] ?? 0.0,
      };
    } else {
      throw Exception('فشل التحقق من الوجه: ${response.statusCode}');
    }
  }

  Future<void> _sendAttendanceConfirmation() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.10:5000/attendance/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.studentId,
          'course_id': widget.courseId,
          'face_verified': true,
          'location_verified': true,
        }),
      );
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الحضور بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل الحضور: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تسجيل الحضور: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من الوجه'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CameraPreview(_cameraController),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _resultMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isVerified ? Colors.green : Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _captureAndVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('التقاط وتحقق'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// مثال على كيفية استخدام الشاشة
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق التعرف على الوجه',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FaceRecognitionScreen(
        studentId: '12345',
        courseId: '101',
      ),
    );
  }
}
