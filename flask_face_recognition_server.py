"""
خادم Flask للتعرف على الوجه باستخدام PyTorch وFaceNet
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import torch
import numpy as np
from PIL import Image
import io
import base64
import os
import json
import logging
from datetime import datetime, timezone
from facenet_pytorch import MTCNN, InceptionResnetV1

# إعداد التسجيل
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# مسارات الملفات
MODELS_DIR = 'models'
DATA_DIR = 'data'
EMBEDDINGS_FILE = os.path.join(DATA_DIR, 'face_embeddings.json')

# إنشاء المجلدات إذا لم تكن موجودة
os.makedirs(MODELS_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)

# تهيئة نماذج التعرف على الوجه
mtcnn = MTCNN(
    image_size=160, 
    margin=20,
    keep_all=False,
    min_face_size=40,
    thresholds=[0.6, 0.7, 0.8],
    factor=0.709,
    post_process=True,
    device='cpu'  # استخدم 'cuda' إذا كان متاحًا
)

# تحميل نموذج InceptionResnetV1 المدرب مسبقًا
model_path = os.path.join(MODELS_DIR, 'facenet_model.pt')
if os.path.exists(model_path):
    logger.info(f"تحميل النموذج من {model_path}")
    resnet = torch.jit.load(model_path)
else:
    logger.info("تحميل نموذج InceptionResnetV1 المدرب مسبقًا")
    resnet = InceptionResnetV1(pretrained='vggface2').eval()
    
    # تصدير النموذج لاستخدامه لاحقًا
    dummy_input = torch.randn(1, 3, 160, 160)
    traced_script_module = torch.jit.trace(resnet, dummy_input)
    traced_script_module.save(model_path)
    logger.info(f"تم حفظ النموذج في {model_path}")

# تحميل تشفيرات الوجوه المخزنة
face_embeddings = {}
if os.path.exists(EMBEDDINGS_FILE):
    try:
        with open(EMBEDDINGS_FILE, 'r') as f:
            data = json.load(f)
            for student_id, embedding_list in data.items():
                face_embeddings[student_id] = torch.tensor(embedding_list)
        logger.info(f"تم تحميل {len(face_embeddings)} تشفير وجه من {EMBEDDINGS_FILE}")
    except Exception as e:
        logger.error(f"خطأ في تحميل تشفيرات الوجوه: {e}")

# عتبات التشابه
SIMILARITY_THRESHOLD = 0.80
SECURITY_MARGIN = 0.30

def save_embeddings():
    """حفظ تشفيرات الوجوه في ملف"""
    data = {}
    for student_id, embedding in face_embeddings.items():
        data[student_id] = embedding.tolist()
    
    with open(EMBEDDINGS_FILE, 'w') as f:
        json.dump(data, f)
    
    logger.info(f"تم حفظ {len(data)} تشفير وجه في {EMBEDDINGS_FILE}")

def calculate_similarity(embedding1, embedding2):
    """حساب التشابه بين تشفيرين"""
    # تطبيع التشفيرات
    embedding1_normalized = torch.nn.functional.normalize(embedding1.unsqueeze(0), p=2, dim=1)
    embedding2_normalized = torch.nn.functional.normalize(embedding2.unsqueeze(0), p=2, dim=1)
    
    # حساب تشابه الجيب تمام (cosine similarity)
    cosine_similarity = torch.mm(embedding1_normalized, embedding2_normalized.t()).item()
    
    # تحويل التشابه إلى نطاق 0-1
    similarity = (cosine_similarity + 1) / 2
    
    return similarity

@app.route('/health', methods=['GET'])
def health_check():
    """التحقق من حالة الخادم"""
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now(timezone.utc).isoformat()
    })

@app.route('/register-face', methods=['POST'])
def register_face():
    """تسجيل وجه جديد"""
    try:
        data = request.json
        student_id = data.get('student_id')
        image_data = data.get('image')
        
        if not student_id or not image_data:
            return jsonify({
                'success': False,
                'message': 'معرف الطالب والصورة مطلوبان'
            }), 400
        
        # فك تشفير الصورة
        image_bytes = base64.b64decode(image_data)
        image = Image.open(io.BytesIO(image_bytes))
        
        # اكتشاف الوجه واستخراج التشفير
        face = mtcnn(image)
        
        if face is None:
            return jsonify({
                'success': False,
                'message': 'لم يتم اكتشاف وجه في الصورة'
            }), 400
        
        # الحصول على التشفير
        with torch.no_grad():
            embedding = resnet(face.unsqueeze(0))[0]
        
        # تخزين التشفير
        face_embeddings[student_id] = embedding
        
        # حفظ التشفيرات
        save_embeddings()
        
        return jsonify({
            'success': True,
            'message': 'تم تسجيل الوجه بنجاح'
        })
    
    except Exception as e:
        logger.error(f"خطأ في تسجيل الوجه: {e}")
        return jsonify({
            'success': False,
            'message': f'خطأ في الخادم: {str(e)}'
        }), 500

@app.route('/attendance/verify-face', methods=['POST'])
def verify_face():
    """التحقق من وجه الطالب"""
    try:
        data = request.json
        student_id = data.get('student_id')
        image_data = data.get('image')
        
        if not student_id or not image_data:
            return jsonify({
                'success': False,
                'message': 'معرف الطالب والصورة مطلوبان'
            }), 400
        
        # التحقق من وجود تشفير مسجل للطالب
        if student_id not in face_embeddings:
            return jsonify({
                'success': False,
                'message': 'لم يتم تسجيل وجه لهذا الطالب'
            }), 400
        
        # فك تشفير الصورة
        image_bytes = base64.b64decode(image_data)
        image = Image.open(io.BytesIO(image_bytes))
        
        # اكتشاف الوجه واستخراج التشفير
        face = mtcnn(image)
        
        if face is None:
            return jsonify({
                'success': False,
                'message': 'لم يتم اكتشاف وجه في الصورة'
            }), 400
        
        # الحصول على التشفير
        with torch.no_grad():
            embedding = resnet(face.unsqueeze(0))[0]
        
        # حساب التشابه مع الوجه المسجل
        known_embedding = face_embeddings[student_id]
        similarity = calculate_similarity(embedding, known_embedding)
        
        # حساب متوسط التشابه مع جميع الوجوه الأخرى المسجلة
        other_similarities = []
        for other_id, other_embedding in face_embeddings.items():
            if other_id != student_id:
                other_similarity = calculate_similarity(embedding, other_embedding)
                other_similarities.append(other_similarity)
        
        # إذا لم تكن هناك وجوه أخرى مسجلة، نستخدم فقط عتبة التشابه
        if len(other_similarities) == 0:
            verified = similarity >= SIMILARITY_THRESHOLD
        else:
            # حساب متوسط التشابه مع الوجوه الأخرى
            avg_other_similarity = sum(other_similarities) / len(other_similarities)
            
            # التحقق من أن التشابه مع الوجه المسجل أعلى بكثير من التشابه مع الوجوه الأخرى
            verified = (similarity >= SIMILARITY_THRESHOLD) and (similarity > avg_other_similarity + SECURITY_MARGIN)
        
        logger.info(f"التحقق من الوجه للطالب {student_id}: التشابه = {similarity:.4f}, النتيجة = {verified}")
        
        # تسجيل التحقق في قاعدة البيانات
        # (هنا يمكن إضافة كود لتسجيل عملية التحقق في قاعدة البيانات)
        
        return jsonify({
            'success': True,
            'verified': verified,
            'similarity': similarity,
            'threshold': SIMILARITY_THRESHOLD,
            'security_margin': SECURITY_MARGIN
        })
    
    except Exception as e:
        logger.error(f"خطأ في التحقق من الوجه: {e}")
        return jsonify({
            'success': False,
            'message': f'خطأ في الخادم: {str(e)}'
        }), 500

@app.route('/attendance/verify', methods=['POST'])
def verify_attendance():
    """تسجيل حضور الطالب"""
    try:
        data = request.json
        student_id = data.get('student_id')
        course_id = data.get('course_id')
        face_verified = data.get('face_verified', False)
        location_verified = data.get('location_verified', False)
        
        if not student_id or not course_id:
            return jsonify({
                'success': False,
                'message': 'معرف الطالب ومعرف المقرر مطلوبان'
            }), 400
        
        # التحقق من أن كلا الشرطين متحققان
        if not face_verified or not location_verified:
            return jsonify({
                'success': False,
                'message': 'يجب التحقق من الوجه والموقع لتسجيل الحضور'
            }), 400
        
        # تسجيل الحضور في قاعدة البيانات
        # (هنا يمكن إضافة كود لتسجيل الحضور في قاعدة البيانات)
        
        logger.info(f"تم تسجيل حضور الطالب {student_id} للمقرر {course_id}")
        
        return jsonify({
            'success': True,
            'message': 'تم تسجيل الحضور بنجاح',
            'student_id': student_id,
            'course_id': course_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        })
    
    except Exception as e:
        logger.error(f"خطأ في تسجيل الحضور: {e}")
        return jsonify({
            'success': False,
            'message': f'خطأ في الخادم: {str(e)}'
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
