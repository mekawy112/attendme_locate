# خطة تحسين نظام التعرف على الوجه باستخدام PyTorch

## المشكلة الحالية
النظام الحالي للتعرف على الوجه يعاني من مشكلة التعرف الخاطئ، حيث يمكن أن يتعرف على أي شخص على أنه الطالب المسجل. هذا يسمح بالتحايل على نظام تسجيل الحضور.

## الحل المقترح
استبدال نموذج التعرف على الوجه الحالي بنموذج أكثر دقة مبني على PyTorch، وتحديداً نموذج FaceNet الذي يوفر دقة أعلى في التعرف على الوجوه.

## خطوات التنفيذ

### 1. إعداد بيئة PyTorch للتطوير
- تثبيت PyTorch على جهاز التطوير
- إعداد بيئة Python لتدريب واختبار النموذج

### 2. تحميل وإعداد نموذج FaceNet المدرب مسبقاً
- استخدام مكتبة facenet-pytorch لتحميل نموذج InceptionResnetV1 المدرب مسبقاً
- اختبار النموذج على مجموعة من الصور للتأكد من دقته

### 3. تحسين النموذج للاستخدام في تطبيق Flutter
- تحويل النموذج إلى صيغة TorchScript للتحسين
- تصدير النموذج بصيغة .pt ليتم استخدامه في التطبيق

### 4. إنشاء واجهة برمجة تطبيقات (API) للتعامل مع النموذج
- إنشاء خدمة Flask تستضيف النموذج
- تطوير نقاط نهاية API للتعرف على الوجه والتحقق من الهوية

### 5. دمج النموذج مع تطبيق Flutter
- إضافة مكتبة PyTorch Mobile إلى مشروع Flutter
- تنفيذ الكود اللازم لتحميل النموذج واستخدامه في التطبيق

### 6. تحسين خوارزمية المقارنة
- تنفيذ مقارنة متعددة المراحل بين الوجه المدخل وصور الطالب المسجلة
- استخدام مقاييس تشابه متعددة (Cosine similarity, Euclidean distance)
- تطبيق عتبات تشابه أكثر صرامة

### 7. تحسين أمان النظام
- تنفيذ اختبار حيوية (Liveness detection) للتأكد من أن المستخدم يستخدم وجهه الحقيقي وليس صورة
- إضافة تقنيات لمنع الهجمات باستخدام الصور أو الفيديوهات المسجلة

### 8. اختبار وتقييم النظام
- اختبار النظام مع مجموعة متنوعة من الوجوه
- قياس معدلات الدقة والخطأ
- تحسين النموذج بناءً على نتائج الاختبار

## التنفيذ التقني

### 1. تثبيت المكتبات اللازمة
```bash
pip install torch torchvision facenet-pytorch flask flask-cors
```

### 2. تحميل وإعداد نموذج FaceNet
```python
from facenet_pytorch import MTCNN, InceptionResnetV1
import torch

# إنشاء نموذج للكشف عن الوجوه
mtcnn = MTCNN(image_size=160, margin=20)

# إنشاء نموذج للتعرف على الوجوه
resnet = InceptionResnetV1(pretrained='vggface2').eval()

# حفظ النموذج بصيغة TorchScript
dummy_input = torch.randn(1, 3, 160, 160)
traced_script_module = torch.jit.trace(resnet, dummy_input)
traced_script_module.save("facenet_model.pt")
```

### 3. إنشاء خدمة Flask للتعرف على الوجه
```python
from flask import Flask, request, jsonify
from flask_cors import CORS
import torch
import numpy as np
from PIL import Image
import io
import base64

app = Flask(__name__)
CORS(app)

# تحميل النموذج
model = torch.jit.load("facenet_model.pt")
model.eval()

@app.route('/verify_face', methods=['POST'])
def verify_face():
    data = request.json
    
    # استخراج الصورة والمعرف من الطلب
    image_data = base64.b64decode(data['image'])
    student_id = data['student_id']
    
    # تحويل الصورة إلى تنسور
    image = Image.open(io.BytesIO(image_data))
    face = mtcnn(image)
    
    if face is None:
        return jsonify({"success": False, "message": "No face detected"})
    
    # الحصول على التشفير من النموذج
    embedding = resnet(face.unsqueeze(0))
    
    # مقارنة التشفير مع التشفيرات المخزنة للطالب
    # (هنا يجب إضافة كود للوصول إلى قاعدة البيانات واسترجاع تشفيرات الطالب)
    
    return jsonify({"success": True, "verified": True})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### 4. دمج النموذج مع تطبيق Flutter
1. إضافة التبعيات اللازمة في ملف `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^0.13.4
  camera: ^0.9.4+5
  path_provider: ^2.0.9
  pytorch_mobile: ^0.2.1
```

2. تنفيذ الكود اللازم لاستخدام النموذج في Flutter:
```dart
import 'package:pytorch_mobile/pytorch_mobile.dart';
import 'package:pytorch_mobile/model.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FaceRecognitionScreen extends StatefulWidget {
  @override
  _FaceRecognitionScreenState createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  Model? _model;
  CameraController? _cameraController;
  bool _isModelReady = false;
  
  @override
  void initState() {
    super.initState();
    _loadModel();
    _initializeCamera();
  }
  
  Future<void> _loadModel() async {
    _model = await PyTorchMobile.loadModel('assets/facenet_model.pt');
    setState(() {
      _isModelReady = true;
    });
  }
  
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
    );
    await _cameraController!.initialize();
    setState(() {});
  }
  
  Future<void> _verifyFace() async {
    if (!_isModelReady || _cameraController == null) return;
    
    final image = await _cameraController!.takePicture();
    final file = File(image.path);
    
    // استخدام النموذج المحلي للتعرف على الوجه
    final prediction = await _model!.getImagePrediction(
      file,
      224,
      224,
      'assets/labels.txt',
    );
    
    // إرسال الصورة إلى الخادم للتحقق
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);
    
    final response = await http.post(
      Uri.parse('http://your-server-url/verify_face'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'image': base64Image,
        'student_id': 'student_id_here',
      }),
    );
    
    final result = jsonDecode(response.body);
    
    if (result['success'] && result['verified']) {
      // تم التحقق بنجاح
    } else {
      // فشل التحقق
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // بناء واجهة المستخدم
  }
}
```

## الفوائد المتوقعة
1. دقة أعلى في التعرف على الوجوه
2. تقليل معدل الخطأ في قبول وجوه غير مصرح بها
3. تحسين أمان نظام تسجيل الحضور
4. تجربة مستخدم أفضل مع استجابة أسرع

## التحديات المحتملة
1. حجم نموذج PyTorch قد يكون كبيراً للتطبيقات المحمولة
2. قد تكون هناك حاجة لتحسين أداء النموذج للأجهزة ذات الموارد المحدودة
3. التكامل بين Flutter وPyTorch قد يتطلب عمل إضافي

## الخلاصة
استخدام نموذج FaceNet المبني على PyTorch سيحسن بشكل كبير دقة نظام التعرف على الوجه، مما سيؤدي إلى نظام تسجيل حضور أكثر أماناً وموثوقية.
