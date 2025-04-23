# تحسين نظام التعرف على الوجه باستخدام PyTorch

هذا المشروع يهدف إلى تحسين نظام التعرف على الوجه في تطبيق Attend Me Locate باستخدام PyTorch ونموذج FaceNet للحصول على دقة أعلى ومنع التحايل على النظام.

## المشكلة

النظام الحالي للتعرف على الوجه يعاني من مشكلة التعرف الخاطئ، حيث يمكن أن يتعرف على أي شخص على أنه الطالب المسجل. هذا يسمح بالتحايل على نظام تسجيل الحضور.

## الحل

استبدال نموذج التعرف على الوجه الحالي بنموذج أكثر دقة مبني على PyTorch، وتحديداً نموذج FaceNet الذي يوفر دقة أعلى في التعرف على الوجوه.

## المميزات الرئيسية

1. **دقة أعلى في التعرف على الوجوه**: استخدام نموذج FaceNet المدرب مسبقاً على مجموعة بيانات VGGFace2.
2. **مقارنة متعددة المراحل**: مقارنة الوجه المدخل مع وجه الطالب المسجل ومع جميع الوجوه الأخرى المسجلة.
3. **هامش أمان عالي**: التأكد من أن التشابه مع وجه الطالب أعلى بكثير من التشابه مع الوجوه الأخرى.
4. **عتبة تشابه عالية**: رفع عتبة التشابه المطلوبة للتحقق من الهوية.
5. **تحسين الصور**: تطبيق تحسينات على الصور لزيادة دقة التعرف.

## متطلبات النظام

### الخادم (Python)
- Python 3.8+
- PyTorch 1.9+
- facenet-pytorch
- Flask
- PIL (Pillow)
- NumPy

### تطبيق الهاتف (Flutter)
- Flutter 2.5+
- camera
- http
- path_provider
- image

## التثبيت

### 1. إعداد بيئة Python
```bash
# إنشاء بيئة افتراضية
python -m venv venv
source venv/bin/activate  # على Linux/Mac
venv\Scripts\activate  # على Windows

# تثبيت المكتبات
pip install torch torchvision facenet-pytorch flask flask-cors pillow numpy
```

### 2. إعداد مشروع Flutter
```bash
# إضافة التبعيات في ملف pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.9.4+5
  http: ^0.13.4
  path_provider: ^2.0.9
  image: ^3.1.0
```

## كيفية الاستخدام

### 1. تشغيل خادم التعرف على الوجه
```bash
python flask_face_recognition_server.py
```

سيبدأ الخادم على المنفذ 5000 وسيكون متاحاً على العنوان `http://localhost:5000`.

### 2. تسجيل وجوه الطلاب
يجب تسجيل وجوه الطلاب قبل استخدام النظام. يمكن القيام بذلك من خلال إرسال طلب POST إلى `/register-face` مع معرف الطالب وصورة الوجه.

### 3. دمج النظام مع تطبيق Flutter
قم بنسخ ملف `flutter_pytorch_integration.dart` إلى مشروع Flutter الخاص بك وتعديله حسب الحاجة.

## الملفات الرئيسية

1. **pytorch_face_recognition_example.py**: نموذج تجريبي لنظام التعرف على الوجه باستخدام PyTorch.
2. **flask_face_recognition_server.py**: خادم Flask للتعرف على الوجه.
3. **flutter_pytorch_integration.dart**: مثال على كيفية دمج النظام مع تطبيق Flutter.

## واجهات API

### 1. تسجيل وجه
- **URL**: `/register-face`
- **Method**: POST
- **Body**:
  ```json
  {
    "student_id": "12345",
    "image": "base64_encoded_image"
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "message": "تم تسجيل الوجه بنجاح"
  }
  ```

### 2. التحقق من الوجه
- **URL**: `/attendance/verify-face`
- **Method**: POST
- **Body**:
  ```json
  {
    "student_id": "12345",
    "image": "base64_encoded_image"
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "verified": true,
    "similarity": 0.92,
    "threshold": 0.80,
    "security_margin": 0.30
  }
  ```

### 3. تسجيل الحضور
- **URL**: `/attendance/verify`
- **Method**: POST
- **Body**:
  ```json
  {
    "student_id": "12345",
    "course_id": "101",
    "face_verified": true,
    "location_verified": true
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "message": "تم تسجيل الحضور بنجاح",
    "student_id": "12345",
    "course_id": "101",
    "timestamp": "2023-04-21T12:34:56.789Z"
  }
  ```

## تحسينات مستقبلية

1. **اختبار حيوية الوجه**: إضافة تقنيات للتأكد من أن المستخدم يستخدم وجهه الحقيقي وليس صورة.
2. **تحسين أداء النموذج**: تقليل حجم النموذج وتحسين سرعته للأجهزة المحمولة.
3. **تدريب النموذج على بيانات محلية**: تدريب النموذج على مجموعة بيانات خاصة بالطلاب لتحسين الدقة.
4. **تكامل أفضل مع Flutter**: استخدام مكتبات مثل pytorch_mobile لتشغيل النموذج محلياً على الجهاز.

## المساهمة

نرحب بالمساهمات! يرجى إرسال طلبات السحب (Pull Requests) أو فتح مشكلات (Issues) للمساعدة في تحسين هذا المشروع.

## الترخيص

هذا المشروع مرخص تحت رخصة MIT.
