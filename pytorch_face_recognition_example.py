"""
نموذج تجريبي لتحسين التعرف على الوجه باستخدام PyTorch وFaceNet
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.mobile_optimizer import optimize_for_mobile
from facenet_pytorch import MTCNN, InceptionResnetV1
import numpy as np
from PIL import Image
import os
import io
import base64

class FaceRecognitionSystem:
    def __init__(self, model_path=None):
        """
        تهيئة نظام التعرف على الوجه
        
        Args:
            model_path: مسار لنموذج محفوظ مسبقًا (اختياري)
        """
        # إنشاء نموذج للكشف عن الوجوه
        self.mtcnn = MTCNN(
            image_size=160, 
            margin=20,
            keep_all=True,
            min_face_size=40,
            thresholds=[0.6, 0.7, 0.8],  # زيادة العتبات لتحسين الدقة
            factor=0.709,
            post_process=True
        )
        
        # إنشاء نموذج للتعرف على الوجوه
        if model_path and os.path.exists(model_path):
            # تحميل نموذج محفوظ مسبقًا
            self.resnet = torch.jit.load(model_path)
        else:
            # استخدام نموذج مدرب مسبقًا
            self.resnet = InceptionResnetV1(pretrained='vggface2').eval()
        
        # تعيين عتبة التشابه
        self.similarity_threshold = 0.85  # عتبة عالية للتشابه
        
        # قاموس لتخزين تشفيرات الوجوه المعروفة
        self.known_face_encodings = {}
    
    def detect_faces(self, image):
        """
        اكتشاف الوجوه في الصورة
        
        Args:
            image: صورة PIL
            
        Returns:
            boxes: مربعات الوجوه المكتشفة
            probs: احتمالات الوجوه
            landmarks: معالم الوجوه
        """
        return self.mtcnn.detect(image, landmarks=True)
    
    def get_face_encoding(self, image, box=None):
        """
        الحصول على تشفير الوجه من صورة
        
        Args:
            image: صورة PIL
            box: مربع الوجه (اختياري)
            
        Returns:
            encoding: تشفير الوجه
        """
        # اقتصاص وتحويل الصورة
        if box is not None:
            face = self.mtcnn.extract(image, [box], save_path=None)[0]
        else:
            face = self.mtcnn(image)
        
        if face is None:
            return None
        
        # الحصول على التشفير
        with torch.no_grad():
            encoding = self.resnet(face.unsqueeze(0))
        
        return encoding[0]
    
    def register_face(self, student_id, images):
        """
        تسجيل وجه طالب باستخدام عدة صور
        
        Args:
            student_id: معرف الطالب
            images: قائمة من صور PIL
            
        Returns:
            success: نجاح العملية
        """
        encodings = []
        
        for image in images:
            boxes, probs, _ = self.detect_faces(image)
            
            if boxes is None or len(boxes) == 0:
                continue
                
            # استخدام الوجه ذو الاحتمالية الأعلى
            best_box_idx = np.argmax(probs)
            encoding = self.get_face_encoding(image, boxes[best_box_idx])
            
            if encoding is not None:
                encodings.append(encoding)
        
        if len(encodings) == 0:
            return False
        
        # التحقق من أن جميع الصور تنتمي لنفس الشخص
        if len(encodings) > 1:
            for i in range(len(encodings) - 1):
                for j in range(i + 1, len(encodings)):
                    similarity = self.calculate_similarity(encodings[i], encodings[j])
                    if similarity < self.similarity_threshold:
                        return False  # الصور لا تنتمي لنفس الشخص
        
        # تخزين متوسط التشفيرات
        avg_encoding = torch.mean(torch.stack(encodings), dim=0)
        self.known_face_encodings[student_id] = avg_encoding
        
        return True
    
    def verify_face(self, student_id, image):
        """
        التحقق من وجه طالب
        
        Args:
            student_id: معرف الطالب
            image: صورة PIL
            
        Returns:
            verified: نتيجة التحقق
            similarity: درجة التشابه
        """
        if student_id not in self.known_face_encodings:
            return False, 0.0
        
        boxes, probs, _ = self.detect_faces(image)
        
        if boxes is None or len(boxes) == 0:
            return False, 0.0
            
        # استخدام الوجه ذو الاحتمالية الأعلى
        best_box_idx = np.argmax(probs)
        encoding = self.get_face_encoding(image, boxes[best_box_idx])
        
        if encoding is None:
            return False, 0.0
        
        # حساب التشابه مع الوجه المسجل
        known_encoding = self.known_face_encodings[student_id]
        similarity = self.calculate_similarity(encoding, known_encoding)
        
        # حساب متوسط التشابه مع جميع الوجوه الأخرى المسجلة
        other_similarities = []
        for other_id, other_encoding in self.known_face_encodings.items():
            if other_id != student_id:
                other_similarity = self.calculate_similarity(encoding, other_encoding)
                other_similarities.append(other_similarity)
        
        # إذا لم تكن هناك وجوه أخرى مسجلة، نستخدم فقط عتبة التشابه
        if len(other_similarities) == 0:
            return similarity >= self.similarity_threshold, similarity
        
        # حساب متوسط التشابه مع الوجوه الأخرى
        avg_other_similarity = sum(other_similarities) / len(other_similarities)
        
        # التحقق من أن التشابه مع الوجه المسجل أعلى بكثير من التشابه مع الوجوه الأخرى
        security_margin = 0.30  # هامش أمان عالي
        verified = (similarity >= self.similarity_threshold) and (similarity > avg_other_similarity + security_margin)
        
        return verified, similarity
    
    def calculate_similarity(self, encoding1, encoding2):
        """
        حساب التشابه بين تشفيرين
        
        Args:
            encoding1: التشفير الأول
            encoding2: التشفير الثاني
            
        Returns:
            similarity: درجة التشابه (0-1)
        """
        # استخدام تشابه الجيب تمام (cosine similarity)
        encoding1_normalized = F.normalize(encoding1.unsqueeze(0), p=2, dim=1)
        encoding2_normalized = F.normalize(encoding2.unsqueeze(0), p=2, dim=1)
        
        cosine_similarity = torch.mm(encoding1_normalized, encoding2_normalized.t()).item()
        
        # تحويل التشابه إلى نطاق 0-1
        similarity = (cosine_similarity + 1) / 2
        
        return similarity
    
    def export_model(self, output_path):
        """
        تصدير النموذج لاستخدامه في تطبيق محمول
        
        Args:
            output_path: مسار الملف الناتج
        """
        # إنشاء مدخل وهمي للنموذج
        dummy_input = torch.randn(1, 3, 160, 160)
        
        # تتبع النموذج
        traced_script_module = torch.jit.trace(self.resnet, dummy_input)
        
        # تحسين النموذج للأجهزة المحمولة
        traced_script_module_optimized = optimize_for_mobile(traced_script_module)
        
        # حفظ النموذج
        traced_script_module_optimized._save_for_lite_interpreter(output_path)
        
        print(f"تم تصدير النموذج إلى {output_path}")


# مثال على استخدام النظام
if __name__ == "__main__":
    # إنشاء نظام التعرف على الوجه
    face_system = FaceRecognitionSystem()
    
    # تسجيل وجه طالب (في تطبيق حقيقي، ستكون هذه صور مختلفة للطالب)
    student_images = [
        Image.open("student1_image1.jpg"),
        Image.open("student1_image2.jpg"),
        Image.open("student1_image3.jpg")
    ]
    
    success = face_system.register_face("student1", student_images)
    print(f"تسجيل الوجه: {'نجاح' if success else 'فشل'}")
    
    # التحقق من وجه الطالب
    test_image = Image.open("test_image.jpg")
    verified, similarity = face_system.verify_face("student1", test_image)
    
    print(f"نتيجة التحقق: {'نجاح' if verified else 'فشل'}")
    print(f"درجة التشابه: {similarity:.4f}")
    
    # تصدير النموذج للاستخدام في تطبيق محمول
    face_system.export_model("facenet_model.pt")
