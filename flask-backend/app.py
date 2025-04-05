from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import logging
import os
import sys  # Add sys import
import time
import jwt as pyjwt
import datetime
from datetime import timezone
from flask_migrate import Migrate
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool
from sqlalchemy import event
from sqlalchemy.engine import Engine
from math import radians, sin, cos, sqrt, atan2  # Add these imports
from werkzeug.security import generate_password_hash, check_password_hash

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# إعداد قاعدة البيانات
basedir = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(basedir, 'database.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
# Add SECRET_KEY for JWT token generation
app.config['SECRET_KEY'] = 'locate-me-secret-key'

app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    'pool_pre_ping': True,
    'pool_recycle': 300,
    'connect_args': {
        'timeout': 20,
        'check_same_thread': False,
    }
}

# Remove the existing set_sqlite_pragma function and replace with this:
@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    try:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")  # Use WAL mode for better concurrency
        cursor.execute("PRAGMA synchronous=NORMAL")  # Slightly less durable but faster
        cursor.execute("PRAGMA busy_timeout=5000")  # Wait up to 5 seconds when database is locked
        cursor.close()
    except Exception as e:
        logger.error(f"Error setting SQLite pragmas: {e}")

db = SQLAlchemy(app)
migrate = Migrate(app, db)

# نموذء البيانات
class Location(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    location = db.Column(db.String(100), nullable=False)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'location': self.location
        }

# نموذء بيانات الطالب
class Student(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.String(50), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)  # Increased length for password hash
    embedding = db.Column(db.Text, nullable=True)  # إضافة عمود التشفير

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)  # Increased length for password hash
    student_id = db.Column(db.String(50), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    role = db.Column(db.String(20), nullable=False)  # 'student' or 'doctor'
    
    def to_dict(self):
        return {
            'id': self.id,
            'email': self.email,
            'student_id': self.student_id,
            'name': self.name,
            'role': self.role
        }

# نموذء بيانات المقررات الدراسية
class Course(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    code = db.Column(db.String(20), unique=True, nullable=False)
    description = db.Column(db.Text, nullable=True)
    doctor_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    enrollment_code = db.Column(db.String(10), unique=True, nullable=False)
    day = db.Column(db.String(50), nullable=True)
    time = db.Column(db.String(50), nullable=True)
    location = db.Column(db.String(100), nullable=True)
    isAttendanceOpen = db.Column(db.Boolean, default=False)

    def to_dict(self):
        students_count = StudentCourse.query.filter_by(course_id=self.id).count()
        return {
            'id': self.id,
            'code': self.code,
            'name': self.name,
            'description': self.description,
            'doctor_id': self.doctor_id,
            'students': students_count,
            'enrollment_code': self.enrollment_code,
            'day': self.day,
            'time': self.time,
            'location': self.location,
            'isAttendanceOpen': self.isAttendanceOpen  # حذف or False
        }

# نموذء العلاقة بين الطلاب والمقررات
class StudentCourse(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    course_id = db.Column(db.Integer, db.ForeignKey('course.id'), nullable=False)
    
    # لضمان عدم تكرار تسجيل الطالب في نفس المقرر
    __table_args__ = (db.UniqueConstraint('student_id', 'course_id'),)

# Add after other models
class StudentLocation(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    course_id = db.Column(db.Integer, db.ForeignKey('course.id'), nullable=False)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.datetime.now)

# نموذج بيانات الحضور
class Attendance(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    course_id = db.Column(db.Integer, db.ForeignKey('course.id'), nullable=False)
    date = db.Column(db.Date, default=datetime.datetime.now().date())
    timestamp = db.Column(db.DateTime, default=datetime.datetime.now())
    face_verified = db.Column(db.Boolean, default=False)
    location_verified = db.Column(db.Boolean, default=False)
    
    # العلاقات
    student = db.relationship('User', backref='attendances')
    course = db.relationship('Course', backref='attendances')

# نموذج بيانات التعرف على الوجه
class FaceRecognition(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.datetime.now())

# الراوترز
@app.route('/', methods=['GET'])
def health_check():
    logger.info(f"Health check endpoint called from {request.remote_addr}")
    try:
        return jsonify({
            "status": "ok",
            "server": "running",
            "database": "connected" if db.session.is_active else "disconnected"
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/data', methods=['GET'])
def get_data():
    try:
        logger.info("GET request received for /data")
        locations = Location.query.all()
        return jsonify([location.to_dict() for location in locations]), 200
    except Exception as e:
        logger.error(f"Error in get_data: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/data', methods=['POST'])
def add_data():
    try:
        data = request.json
        print(f"Received data: {data}")  # إضافة هذا السطر للتأكد من البيانات
        if not data or 'name' not in data or 'location' not in data:
            raise ValueError("Missing required fields 'name' or 'location'")
        new_location = Location(name=data.get('name'), location=data.get('location'))
        db.session.add(new_location)
        db.session.commit()
        print("Data saved successfully")  # وهذا السطر للتأكد من الحفظ
        return jsonify({'message': 'Added successfully'}), 201
    except Exception as e:
        print(f"Error: {e}")  # وهذا للأخطاء
        return jsonify({"error": str(e)}), 500

@app.route('/user/login', methods=['POST'])
def login():
    try:
        data = request.json
        if not data:
            app.logger.warning('Login attempt with no data provided')
            return jsonify({
                'success': False,
                'message': 'No data provided'
            }), 400
            
        # Trim email to remove any leading/trailing whitespace
        email = data.get('email')
        if email:
            email = email.strip()
        password = data.get('password')
        
        if not email or not password:
            app.logger.warning(f'Login attempt with missing credentials: email={bool(email)}, password={bool(password)}')
            return jsonify({
                'success': False,
                'message': 'Email and password are required'
            }), 400

        # Find the user
        user = User.query.filter_by(email=email).first()
        
        if not user:
            app.logger.warning(f'Login attempt failed: user not found for email {email}')
            return jsonify({
                'success': False,
                'message': 'Invalid email or password'
            }), 401

        # تحسين التحقق من كلمة المرور وإضافة المزيد من التفاصيل في السجل
        try:
            # طباعة معلومات تصحيح الأخطاء لفهم المشكلة
            app.logger.debug(f'Stored password hash: {user.password}')
            app.logger.debug(f'Password type: {type(password)}')
            
            # التحقق من صحة كلمة المرور
            if not check_password_hash(user.password, password):
                app.logger.warning(f'Login attempt failed: invalid password for email {email}. Password hash mismatch.')
                return jsonify({
                    'success': False,
                    'message': 'Invalid email or password'
                }), 401
        except Exception as e:
            app.logger.error(f'Error during password verification for email {email}: {str(e)}')
            return jsonify({
                'success': False,
                'message': 'An error occurred during login'
            }), 500

        # Generate JWT token
        token_payload = {
            'user_id': str(user.id),
            'email': user.email,
            'role': user.role,
            'exp': datetime.datetime.now(timezone.utc) + datetime.timedelta(days=1)
        }
        
        # Use pyjwt instead of jwt
        token = pyjwt.encode(
            token_payload, 
            app.config['SECRET_KEY'], 
            algorithm='HS256'
        )
        
        # If token is returned as bytes, decode to string
        if isinstance(token, bytes):
            token = token.decode('utf-8')
        
        app.logger.info(f'Successful login for user: {email}')
        return jsonify({
            'success': True,
            'message': 'Login successful',
            'token': token,
            'user': user.to_dict()
        }), 200

    except Exception as e:
        app.logger.error(f'Error in login: {str(e)}')
        return jsonify({
            'success': False,
            'message': 'An error occurred during login'
        }), 500

# Add this new route
@app.route('/signup', methods=['POST'])
def signup():
    try:
        data = request.json
        logger.info(f"Received signup request with data: {data}")
        
        # Validate required fields
        required_fields = ['email', 'password', 'student_id', 'name', 'role']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'success': False,
                    'message': f'Missing required field: {field}'
                }), 400
                
        # Trim email and student_id to remove any leading/trailing whitespace
        if 'email' in data:
            data['email'] = data['email'].strip()
        if 'student_id' in data:
            data['student_id'] = data['student_id'].strip()
        if 'name' in data:
            data['name'] = data['name'].strip()

        # Check if user already exists
        existing_user = User.query.filter(
            (User.email == data['email']) | 
            (User.student_id == data['student_id'])
        ).first()
        
        if existing_user:
            return jsonify({
                'success': False,
                'message': 'Email or Student ID already registered'
            }), 400

        # Hash password before storing - use method='pbkdf2:sha256' for better security
        hashed_password = generate_password_hash(data['password'], method='pbkdf2:sha256')
        
        # Log the password hash for debugging
        logger.debug(f"Generated password hash: {hashed_password}")

        # Create new user
        new_user = User(
            email=data['email'],
            password=hashed_password,
            student_id=data['student_id'],
            name=data['name'],
            role=data['role']
        )
        
        db.session.add(new_user)
        db.session.commit()
        
        logger.info(f"Successfully created new user: {new_user.email}")
        return jsonify({
            'success': True,
            'message': 'Registration successful'
        }), 201
    
    except Exception as e:
        logger.error(f"Error in signup: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# إضافة مقرر دراسي جديد (للدكتور فقط)
@app.route('/courses', methods=['POST'])
def add_course():
    try:
        data = request.json
        logger.info(f"Received add course request with data: {data}")
        
        # التحقق من البيانات المطلوبة
        required_fields = ['code', 'name', 'description', 'doctor_id']
        for field in required_fields:
            if field not in data or not data[field]:
                logger.error(f"Missing required field: {field}")
                return jsonify({
                    'success': False,
                    'message': f'Missing required field: {field}'
                }), 400
        
        # التحقق من وجود حقول اليوم والوقت والموقع (غير إلزامية ولكن يجب التحقق منها)
        if 'day' not in data:
            data['day'] = ''
            logger.info("Day field not provided, using empty string")
        if 'time' not in data:
            data['time'] = ''
            logger.info("Time field not provided, using empty string")
        if 'location' not in data:
            data['location'] = ''
            logger.info("Location field not provided, using empty string")
        
        # التحقق من أن المستخدم دكتور
        doctor = User.query.filter_by(id=data['doctor_id'], role='doctor').first()
        if not doctor:
            logger.error(f"User with ID {data['doctor_id']} is not a doctor or does not exist")
            return jsonify({
                'success': False,
                'message': 'Unauthorized: Only doctors can add courses'
            }), 403
        
        # التحقق من عدم وجود مقرر بنفس الكود
        existing_course = Course.query.filter_by(code=data['code']).first()
        if (existing_course):
            logger.error(f"Course with code {data['code']} already exists")
            return jsonify({
                'success': False,
                'message': 'Course code already exists'
            }), 400
        
        # Generate a unique enrollment code (alphanumeric, 6 characters)
        import random
        import string
        
        def generate_enrollment_code():
            # Generate a random 6-character alphanumeric code
            chars = string.ascii_uppercase + string.digits
            code = ''.join(random.choice(chars) for _ in range(6))
            
            # Check if the code already exists
            existing = Course.query.filter_by(enrollment_code=code).first()
            if existing:
                # If code exists, generate a new one recursively
                return generate_enrollment_code()
            return code
        
        # Generate a unique enrollment code
        enrollment_code = generate_enrollment_code()
        logger.info(f"Generated enrollment code: {enrollment_code}")
        
        # إنشاء مقرر جديد
        new_course = Course(
            code=data['code'],
            name=data['name'],
            description=data['description'],
            doctor_id=data['doctor_id'],
            enrollment_code=enrollment_code,
            day=data.get('day', ''),
            time=data.get('time', ''),
            location=data.get('location', '')  # Add this line
        )
        
        logger.info(f"Attempting to add new course: {new_course.code}")
        db.session.add(new_course)
        db.session.commit()
        logger.info(f"Successfully added course to database")
        
        logger.info(f"Successfully created new course: {new_course.code} with enrollment code: {enrollment_code}")
        return jsonify({
            'success': True,
            'message': 'Course added successfully',
            'course': new_course.to_dict()
        }), 201
    
    except Exception as e:
        logger.error(f"Error in add_course: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# الحصول على مقررات الدكتور
@app.route('/courses/doctor/<int:doctor_id>', methods=['GET'])
def get_doctor_courses(doctor_id):
    try:
        # تعديل في ملف app.py:
        
        # لضمان توافق أفضل، يمكننا أيضًا تعديل ملف `app.py` للتعامل مع معرف الدكتور بشكل أكثر مرونة:
        try:
            doctor_id = int(doctor_id)
        except ValueError:
            logger.error(f"Invalid doctor_id format: {doctor_id}")
            return jsonify({
                'success': False,
                'message': 'Invalid doctor ID format'
            }), 400
            
        # التحقق من أن المستخدم دكتور
        doctor = User.query.filter_by(id=doctor_id, role='doctor').first()
        if not doctor:
            return jsonify({
                'success': False,
                'message': 'Unauthorized: Invalid doctor ID'
            }), 403
        
        # الحصول على مقررات الدكتور
        courses = Course.query.filter_by(doctor_id=doctor_id).all()
        
        return jsonify({
            'success': True,
            'courses': [course.to_dict() for course in courses]
        }), 200
    
    except Exception as e:
        logger.error(f"Error in get_doctor_courses: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# حذف مقرر دراسي (للدكتور فقط)
@app.route('/courses/<int:course_id>', methods=['DELETE'])
def delete_course(course_id):
    try:
        data = request.json
        doctor_id = data.get('doctor_id')
        
        if not doctor_id:
            return jsonify({
                'success': False,
                'message': 'Missing doctor_id'
            }), 400
        
        # التحقق من وجود المقرر
        course = Course.query.get(course_id)
        if not course:
            return jsonify({
                'success': False,
                'message': 'Course not found'
            }), 404
        
        # التحقق من أن الدكتور هو مالك المقرر
        if course.doctor_id != doctor_id:
            return jsonify({
                'success': False,
                'message': 'Unauthorized: You can only delete your own courses'
            }), 403
        
        # حذف جميع علاقات الطلاب بالمقرر أولاً
        StudentCourse.query.filter_by(course_id=course_id).delete()
        
        # حذف المقرر
        db.session.delete(course)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Course deleted successfully'
        }), 200
    
    except Exception as e:
        logger.error(f"Error in delete_course: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# تسجيل طالب في مقرر باستخدام كود التسجيل
@app.route('/courses/enroll', methods=['POST'])
def enroll_in_course():
    try:
        data = request.get_json()
        student_id = data.get('student_id')  # Could be string or int
        enrollment_code = data.get('enrollment_code')  # Should be string
        
        if not student_id or not enrollment_code:
            return jsonify({
                'success': False,
                'message': 'Missing student_id or enrollment_code'
            }), 400
        
        # Always convert student_id to int for database operations
        try:
            student_id = int(student_id)
        except ValueError:
            logger.error(f"Invalid student_id format: {student_id}")
            return jsonify({
                'success': False,
                'message': 'Invalid student ID format'
            }), 400
        
        # Find the student
        student = User.query.filter_by(id=student_id, role='student').first()
        if not student:
            return jsonify({
                'success': False,
                'message': 'Unauthorized: Invalid student ID'
            }), 403
        
        # Find the course by enrollment code
        course = Course.query.filter_by(enrollment_code=enrollment_code).first()
        if not course:
            return jsonify({
                'success': False,
                'message': 'Invalid enrollment code'
            }), 404
        
        # Check if already enrolled
        existing_enrollment = StudentCourse.query.filter_by(
            student_id=student_id, 
            course_id=course.id
        ).first()
        
        if existing_enrollment:
            return jsonify({
                'success': False,
                'message': 'You are already enrolled in this course'
            }), 400
        
        # Create new enrollment
        new_enrollment = StudentCourse(
            student_id=student_id,
            course_id=course.id
        )
        
        # Use a separate transaction with timeout
        max_retries = 3
        retry_count = 0
        
        while retry_count < max_retries:
            try:
                db.session.add(new_enrollment)
                db.session.commit()
                break
            except Exception as e:
                retry_count += 1
                logger.warning(f"Retry {retry_count}/{max_retries} for enrollment: {e}")
                db.session.rollback()
                time.sleep(1)  # Wait before retrying
                
                if retry_count >= max_retries:
                    raise
        
        return jsonify({
            'success': True,
            'message': 'Successfully enrolled in course',
            'course': course.to_dict()
        }), 201
        
    except Exception as e:
        logger.error(f"Error in enroll_in_course: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# الحصول على مقررات الطالب
@app.route('/courses/student/<student_id>', methods=['GET'])
def get_student_courses(student_id):
    try:
        # Convert student_id to integer
        try:
            student_id = int(student_id)
        except ValueError:
            logger.error(f"Invalid student_id format: {student_id}")
            return jsonify({
                'success': False,
                'message': 'Invalid student ID format'
            }), 400
            
        # التحقق من أن المستخدم طالب
        student = User.query.filter_by(id=student_id, role='student').first()
        if not student:
            return jsonify({
                'success': False,
                'message': 'Unauthorized: Invalid student ID'
            }), 403
        
        # الحصول على معرفات المقررات المسجل فيها الطالب
        enrollments = StudentCourse.query.filter_by(student_id=student_id).all()
        course_ids = [enrollment.course_id for enrollment in enrollments]
        
        # الحصول على تفاصيل المقررات
        courses = Course.query.filter(Course.id.in_(course_ids)).all()
        
        return jsonify({
            'success': True,
            'courses': [course.to_dict() for course in courses]
        }), 200
    
    except Exception as e:
        logger.error(f"Error in get_student_courses: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# Make sure there's no incomplete try block before this line
@app.route('/courses/<int:course_id>/students', methods=['GET'])
def get_course_students(course_id):
    try:
        # التحقق من وجود المقرر
        course = Course.query.get(course_id)
        if not course:
            return jsonify({
                'success': False,
                'message': 'Course not found'
            }), 404
        
        # الحصول على معرفات الطلاب المسجلين في المقرر
        enrollments = StudentCourse.query.filter_by(course_id=course_id).all()
        student_ids = [enrollment.student_id for enrollment in enrollments]
        
        # الحصول على تفاصيل الطلاب
        students = User.query.filter(User.id.in_(student_ids)).all()
        
        return jsonify({
            'success': True,
            'students': [student.to_dict() for student in students]
        }), 200
        
    except Exception as e:
        logger.error(f"Error in get_course_students: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# إلغاء تسجيل طالب من مقرر
@app.route('/courses/unenroll', methods=['POST'])
def unenroll_from_course():
    try:
        data = request.json
        student_id = data.get('student_id')
        course_id = data.get('course_id')
        
        if not student_id or not course_id:
            return jsonify({
                'success': False,
                'message': 'Missing student_id or course_id'
            }), 400
        
        # التحقق من أن المستخدم طالب
        student = User.query.filter_by(id=student_id, role='student').first()
        if not student:
            return jsonify({
                'success': False,
                'message': 'Unauthorized: Invalid student ID'
            }), 403
        
        # البحث عن التسجيل
        enrollment = StudentCourse.query.filter_by(
            student_id=student_id, 
            course_id=course_id
        ).first()
        
        if not enrollment:
            return jsonify({
                'success': False,
                'message': 'Student is not enrolled in this course'
            }), 404
        
        # إلغاء التسجيل
        db.session.delete(enrollment)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Unenrolled from course successfully'
        }), 200
    
    except Exception as e:
        logger.error(f"Error in unenroll_from_course: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/db-status', methods=['GET'])
def db_status():
    try:
        # التحقق من اتصال قاعدة البيانات
        db_connected = db.session.is_active
        
        # التحقق من وجود الجداول
        tables = {
            'User': User.query.count(),
            'Course': Course.query.count(),
            'StudentCourse': StudentCourse.query.count(),
            'Location': Location.query.count()
        }
        
        return jsonify({
            'success': True,
            'db_connected': db_connected,
            'tables': tables
        }), 200
    except Exception as e:
        logger.error(f"Error checking database status: {e}")
        return jsonify({
            'success': False,
            'message': f'Error checking database status: {str(e)}'
        }), 500

@app.route('/user', methods=['GET'])
def get_current_user():
    try:
        # Get token from Authorization header
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({
                'success': False,
                'message': 'Missing or invalid token'
            }), 401
        
        token = auth_header.split(' ')[1]
        
        # Verify token and get user ID
        # This is a simplified example - implement proper JWT verification
        # For example, using PyJWT library
        
        # For now, let's assume we can extract user_id from token
        # In a real app, you'd decode and verify the JWT token
        user_id = extract_user_id_from_token(token)
        
        if not user_id:
            return jsonify({
                'success': False,
                'message': 'Invalid token'
            }), 401
        
        # Get user from database
        user = User.query.get(user_id)
        if not user:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
        
        return jsonify({
            'success': True,
            'user': user.to_dict()
        }), 200
    
    except Exception as e:
        logger.error(f"Error in get_current_user: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

def extract_user_id_from_token(token):
    try:
        payload = pyjwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
        return payload.get('user_id')
    except pyjwt.ExpiredSignatureError:
        logger.error("Token expired")
        return None
    except pyjwt.InvalidTokenError as e:
        logger.error(f"Invalid token: {e}")
        return None
    except Exception as e:
        logger.error(f"Error extracting user ID from token: {e}")
        return None

@app.route('/courses/<int:course_id>/attendance', methods=['PUT'])
def update_attendance_state(course_id):
    try:
        data = request.get_json()
        max_retries = 5
        retry_count = 0
        retry_delay = 1  # seconds

        while retry_count < max_retries:
            try:
                # Use session.get() instead of query.get()
                course = db.session.get(Course, course_id)
                
                if not course:
                    return jsonify({
                        'success': False, 
                        'message': 'Course not found'
                    }), 404

                # Set the new attendance state
                new_state = data.get('isAttendanceOpen', False)
                course.isAttendanceOpen = new_state
                
                # Use a shorter transaction
                db.session.begin_nested()
                db.session.commit()
                
                # Double-check the change was saved
                db.session.refresh(course)
                
                if course.isAttendanceOpen == new_state:
                    return jsonify({
                        'success': True,
                        'message': 'Attendance state updated successfully',
                        'isAttendanceOpen': course.isAttendanceOpen
                    })
                else:
                    raise Exception("Failed to verify state change")
                
            except Exception as inner_error:
                retry_count += 1
                db.session.rollback()
                
                if retry_count >= max_retries:
                    logger.error(f"Failed after {max_retries} attempts: {inner_error}")
                    raise
                
                logger.warning(f"Retry {retry_count}/{max_retries} after error: {inner_error}")
                time.sleep(retry_delay)
                
    except Exception as e:
        logger.error(f"Error updating attendance state: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371000  # Earth's radius in meters

    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    distance = R * c
    
    return distance

@app.route('/attendance/verify-location', methods=['POST'])
def verify_location():
    try:
        data = request.get_json()
        logger.info(f"Received location data: {data}")  # Add logging
        
        # Get student location from request
        try:
            student_lat = float(data.get('latitude'))
            student_lon = float(data.get('longitude'))
            student_id = data.get('student_id')
            course_id = data.get('course_id')
        except (ValueError, TypeError) as e:
            logger.error(f"Error parsing student location: {e}")
            return jsonify({
                'success': False,
                'message': 'Invalid student location format'
            }), 400

        # Get course from database
        course = db.session.get(Course, course_id)
        if not course:
            return jsonify({
                'success': False,
                'message': 'Course not found'
            }), 404

        # Parse course location
        try:
            if not course.location or ',' not in course.location:
                return jsonify({
                    'success': False,
                    'message': 'Course location not set'
                }), 400

            course_location = course.location.split(',')
            if len(course_location) != 2:
                return jsonify({
                    'success': False,
                    'message': 'Invalid course location format'
                }), 400

            course_lat = float(course_location[0].strip())
            course_lon = float(course_location[1].strip())
        except (ValueError, AttributeError) as e:
            logger.error(f"Error parsing course location: {e}")
            return jsonify({
                'success': False,
                'message': f'Invalid course location format: {e}'
            }), 400

        # Calculate distance
        distance = calculate_distance(
            student_lat, student_lon,
            course_lat, course_lon
        )

        logger.info(f"Calculated distance: {distance}m")

        # Check if within range (30 meters)
        if distance <= 30:
            # Save the attendance record
            attendance = StudentLocation(
                student_id=student_id,
                course_id=course_id,
                latitude=student_lat,
                longitude=student_lon
            )
            db.session.add(attendance)
            db.session.commit()

            return jsonify({
                'success': True,
                'message': 'Attendance recorded successfully',
                'distance': distance
            })
        else:
            return jsonify({
                'success': False,
                'message': f'Too far from class location ({distance:.1f}m)',
                'distance': distance
            })

    except Exception as e:
        logger.error(f"Error verifying location: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/attendance/verify', methods=['POST'])
def verify_attendance():
    try:
        data = request.get_json()
        student_id = data.get('student_id')
        course_id = data.get('course_id')
        
        # Check for required records
        if not student_id or not course_id:
            return jsonify({
                'success': False,
                'message': 'Missing student_id or course_id'
            }), 400
        
        # Extract face verification status from sent data
        face_verified = data.get('face_verified', False)
        
        # Extract location verification status from sent data
        location_verified = data.get('location_verified', False)
        
        # Check that both conditions are met
        if not face_verified or not location_verified:
            return jsonify({
                'success': False,
                'message': 'Both face and location verification are required to mark attendance'
            }), 400
        
        # Check first if student already has attendance for this course today
        now = datetime.datetime.now()
        today = now.date()
        existing_attendance = Attendance.query.filter_by(
            student_id=student_id,
            course_id=course_id,
            date=today
        ).first()
        
        if existing_attendance:
            # Get course name for notification
            course = Course.query.get(course_id)
            course_name = course.name if course else "Unknown Course"
            
            return jsonify({
                'success': True,
                'already_recorded': True,
                'message': 'Your attendance has already been recorded for this course today',
                'course_name': course_name
            }), 200
        
        # Check face recognition record in database
        face_record = FaceRecognition.query.filter_by(
            student_id=student_id
        ).order_by(FaceRecognition.timestamp.desc()).first()
        
        if not face_record:
            return jsonify({
                'success': False,
                'message': 'Face verification not found in database'
            }), 400
        
        # Check if face recognition was done in the last 15 minutes
        face_time_diff = (now - face_record.timestamp).total_seconds()
        if face_time_diff > 15 * 60:  # 15 minutes
            return jsonify({
                'success': False,
                'message': 'Face verification expired, please verify again'
            }), 400
        
        # Check location verification status in database
        location_record = StudentLocation.query.filter_by(
            student_id=student_id,
            course_id=course_id
        ).order_by(StudentLocation.timestamp.desc()).first()
        
        if not location_record:
            return jsonify({
                'success': False,
                'message': 'Location verification not found in database'
            }), 400
        
        # Check if location verification was done in the last 15 minutes
        location_time_diff = (now - location_record.timestamp).total_seconds()
        if location_time_diff > 15 * 60:  # 15 minutes
            return jsonify({
                'success': False,
                'message': 'Location verification expired, please verify again'
            }), 400
        
        # Log verification attempt
        app.logger.info(f"Attendance verification: student_id={student_id}, course_id={course_id}, face={face_verified}, location={location_verified}")
        
        # If all conditions are met, record attendance
        attendance = Attendance(
            student_id=student_id,
            course_id=course_id,
            face_verified=face_verified,
            location_verified=location_verified,
            timestamp=now
        )
        db.session.add(attendance)
        db.session.commit()
        
        # Get course name for response
        course = Course.query.get(course_id)
        course_name = course.name if course else "Unknown Course"
        
        return jsonify({
            'success': True,
            'already_recorded': False,
            'message': 'Attendance recorded successfully',
            'course_name': course_name
        }), 200
        
    except Exception as e:
        logger.error(f"Error verifying attendance: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/attendance/confirm', methods=['POST'])
def confirm_attendance():
    try:
        data = request.get_json()
        student_id = data.get('student_id')
        course_id = data.get('course_id')
        
        # Check for required records
        if not student_id or not course_id:
            return jsonify({
                'success': False,
                'message': 'Missing student_id or course_id'
            }), 400
        
        # Search for face recognition record by student ID
        face_record = FaceRecognition.query.filter_by(
            student_id=student_id
        ).order_by(FaceRecognition.timestamp.desc()).first()
        
        if not face_record:
            return jsonify({
                'success': False,
                'message': 'Face verification not found in database'
            }), 400
        
        # Check if face recognition was done in the last 15 minutes
        now = datetime.datetime.now()
        face_time_diff = (now - face_record.timestamp).total_seconds()
        if face_time_diff > 15 * 60:  # 15 minutes
            return jsonify({
                'success': False,
                'message': 'Face verification expired, please verify again'
            }), 400
        
        # Search for location verification record by student ID and course ID
        location_record = StudentLocation.query.filter_by(
            student_id=student_id,
            course_id=course_id
        ).order_by(StudentLocation.timestamp.desc()).first()
        
        if not location_record:
            return jsonify({
                'success': False,
                'message': 'Location verification not found in database'
            }), 400
        
        # Check if location verification was done in the last 15 minutes
        location_time_diff = (now - location_record.timestamp).total_seconds()
        if location_time_diff > 15 * 60:  # 15 minutes
            return jsonify({
                'success': False,
                'message': 'Location verification expired, please verify again'
            }), 400
        
        # If all conditions are met, record attendance
        attendance = Attendance(
            student_id=student_id,
            course_id=course_id,
            face_verified=True,
            location_verified=True,
            timestamp=now
        )
        db.session.add(attendance)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Attendance confirmed successfully'
        }), 200
        
    except Exception as e:
        logger.error(f"Error confirming attendance: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/attendance/send-to-doctor', methods=['POST'])
def send_attendance_to_doctor():
    try:
        data = request.get_json()
        course_id = data.get('course_id')
        date_str = data.get('date')  # Optional
        
        if not course_id:
            return jsonify({
                'success': False,
                'message': 'Missing course_id'
            }), 400
        
        # Initialize database query
        query = db.session.query(
            Attendance, User.name.label('student_name')
        ).join(
            User, Attendance.student_id == User.id
        ).filter(
            Attendance.course_id == course_id,
            Attendance.face_verified == True,
            Attendance.location_verified == True
        )
        
        # If date is specified, filter results by date
        if date_str:
            try:
                filter_date = datetime.datetime.strptime(date_str, "%Y-%m-%d").date()
                query = query.filter(Attendance.date == filter_date)
            except ValueError:
                return jsonify({
                    'success': False,
                    'message': 'Invalid date format, use YYYY-MM-DD'
                }), 400
        
        # Get results
        attendances = query.all()
        
        # Format data for return
        attendance_records = []
        for attendance, student_name in attendances:
            attendance_records.append({
                'student_id': attendance.student_id,
                'student_name': student_name,
                'date': attendance.date.strftime("%Y-%m-%d"),
                'timestamp': attendance.timestamp.strftime("%H:%M:%S")
            })
        
        # Return data to doctor
        return jsonify({
            'success': True,
            'course_id': course_id,
            'attendance_records': attendance_records
        }), 200
        
    except Exception as e:
        logger.error(f"Error sending attendance to doctor: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# New API interface for doctor to view attendance records
@app.route('/doctor/course-attendance', methods=['GET'])
def get_course_attendance():
    try:
        course_id = request.args.get('course_id')
        date_str = request.args.get('date')  # Optional
        student_id = request.args.get('student_id')  # Student ID for search (optional)
        
        if not course_id:
            return jsonify({
                'success': False,
                'message': 'Missing course_id parameter'
            }), 400
        
        # Get course
        course = Course.query.get(course_id)
        if not course:
            return jsonify({
                'success': False,
                'message': 'Course not found'
            }), 404
        
        # Determine date for filtering
        if date_str:
            try:
                filter_date = datetime.datetime.strptime(date_str, "%Y-%m-%d").date()
            except ValueError:
                return jsonify({
                    'success': False,
                    'message': 'Invalid date format, use YYYY-MM-DD'
                }), 400
        else:
            filter_date = datetime.datetime.now().date()
        
        # Get all students enrolled in the course
        enrollments = StudentCourse.query.filter_by(course_id=course_id).all()
        student_ids = [enrollment.student_id for enrollment in enrollments]
        
        # Filter by student ID if provided
        if student_id:
            try:
                student_id_int = int(student_id)
                # Check if student is enrolled in the course
                if student_id_int in student_ids:
                    student_ids = [student_id_int]
                else:
                    return jsonify({
                        'success': False,
                        'message': 'Student not enrolled in this course'
                    }), 404
            except ValueError:
                return jsonify({
                    'success': False,
                    'message': 'Invalid student_id format'
                }), 400
        
        # Get student details
        students = User.query.filter(User.id.in_(student_ids)).all()
        
        # Get attendance records for the specified date
        attendance_records = Attendance.query.filter(
            Attendance.course_id == course_id,
            Attendance.date == filter_date,
            Attendance.face_verified == True,
            Attendance.location_verified == True
        ).all()
        
        # Create a dictionary for easy lookup of attended students
        attended_students = {record.student_id: record for record in attendance_records}
        
        # Format data for return
        attendance_data = []
        for student in students:
            # Check if student is present
            is_present = student.id in attended_students
            attendance_record = attended_students.get(student.id)
            
            student_data = {
                'student_id': student.id,
                'student_number': student.student_id,  # Student number
                'student_name': student.name,
                'is_present': is_present,
                'attendance_date': filter_date.strftime("%Y-%m-%d"),
            }
            
            # Add attendance time if student is present
            if is_present and attendance_record:
                student_data['attendance_time'] = attendance_record.timestamp.strftime("%H:%M:%S")
            
            attendance_data.append(student_data)
        
        # Calculate attendance statistics
        total_students = len(students)
        present_students = len(attended_students)
        absence_students = total_students - present_students
        attendance_percentage = (present_students / total_students * 100) if total_students > 0 else 0
        
        return jsonify({
            'success': True,
            'course_id': course_id,
            'course_name': course.name,
            'date': filter_date.strftime("%Y-%m-%d"),
            'total_students': total_students,
            'present_students': present_students,
            'absence_students': absence_students,
            'attendance_percentage': round(attendance_percentage, 2),
            'students': attendance_data
        }), 200
        
    except Exception as e:
        logger.error(f"Error getting course attendance: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/face/check-registration/<int:student_id>', methods=['GET'])
def check_face_registration(student_id):
    student = Student.query.get(student_id)
    if not student:
        return jsonify({'isRegistered': False, 'message': 'Student not found'}), 404

    if student.face_registered:
        return jsonify({'isRegistered': True})
    else:
        return jsonify({'isRegistered': False})

def cleanup_database():
    try:
        with app.app_context():
            db.session.remove()
            db.engine.dispose()
    except Exception as e:
        logger.error(f"Error during database cleanup: {e}")

def kill_database_connections():
    try:
        # Force close all database connections
        with app.app_context():
            db.session.remove()
            db.engine.dispose()
            # Add a short sleep to ensure connections are properly closed
            time.sleep(1.5)  # Increase timeout to give more time for connections to close
    except Exception as e:
        logger.error(f"Error killing database connections: {e}")

# Add new route for face verification
@app.route('/attendance/verify-face', methods=['POST'])
def verify_face():
    try:
        data = request.get_json()
        student_id = data.get('student_id')
        
        # Check for student ID
        if not student_id:
            return jsonify({
                'success': False,
                'message': 'Missing student_id'
            }), 400
        
        # Record face verification in database
        face_recognition = FaceRecognition(
            student_id=student_id,
            timestamp=datetime.datetime.now()
        )
        db.session.add(face_recognition)
        db.session.commit()
        
        logger.info(f"Face verification recorded for student_id={student_id}")
        
        return jsonify({
            'success': True,
            'message': 'Face verification recorded successfully'
        }), 200
        
    except Exception as e:
        logger.error(f"Error recording face verification: {e}")
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# New interface for doctor to get attendance dates
@app.route('/doctor/course-attendance/dates', methods=['GET'])
def get_course_attendance_dates():
    try:
        course_id = request.args.get('course_id')
        
        if not course_id:
            return jsonify({
                'success': False,
                'message': 'Missing course_id parameter'
            }), 400
        
        # Check if course exists
        course = Course.query.get(course_id)
        if not course:
            return jsonify({
                'success': False,
                'message': 'Course not found'
            }), 404
        
        # Get unique attendance dates for the course
        dates = db.session.query(Attendance.date)\
            .filter(Attendance.course_id == course_id)\
            .distinct()\
            .all()
        
        # Format dates as strings
        date_strings = [date[0].strftime("%Y-%m-%d") for date in dates]
        
        return jsonify({
            'success': True,
            'course_id': course_id,
            'course_name': course.name,
            'dates': date_strings
        }), 200
        
    except Exception as e:
        logger.error(f"Error getting course attendance dates: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/attendance/course/<int:course_id>/date/<date>', methods=['GET'])
def get_course_attendance_by_date(course_id, date):
    try:
        # Check if course exists
        course = Course.query.get(course_id)
        if not course:
            return jsonify({'success': False, 'message': 'Course not found'}), 404
        
        # Convert date to date object
        try:
            attendance_date = datetime.datetime.strptime(date, '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid date format. Use YYYY-MM-DD'}), 400
        
        # Get attendance records for the course and date
        attendance_records = Attendance.query.filter_by(
            course_id=course_id,
            date=attendance_date
        ).all()
        
        # Format data for return
        attendance_data = []
        for record in attendance_records:
            student = User.query.get(record.student_id)
            if student:
                attendance_data.append({
                    'id': student.id,
                    'name': student.name,
                    'email': student.email,
                    'timestamp': record.timestamp.isoformat(),
                    'face_verified': record.face_verified,
                    'location_verified': record.location_verified
                })
        
        return jsonify({
            'success': True,
            'message': 'Attendance records retrieved successfully',
            'attendance_records': attendance_data
        })
    
    except Exception as e:
        app.logger.error(f"Error getting attendance records by date: {e}")
        return jsonify({'success': False, 'message': f'Error: {str(e)}'}), 500

@app.route('/doctor/course-attendance/summary', methods=['GET'])
def get_course_attendance_summary():
    try:
        course_id = request.args.get('course_id')
        
        if not course_id:
            return jsonify({
                'success': False,
                'message': 'Missing course_id parameter'
            }), 400
        
        # Check if course exists
        course = Course.query.get(course_id)
        if not course:
            return jsonify({
                'success': False,
                'message': 'Course not found'
            }), 404
        
        # Get all students enrolled in the course
        enrollments = StudentCourse.query.filter_by(course_id=course_id).all()
        student_ids = [enrollment.student_id for enrollment in enrollments]
        
        # Get student details
        students = User.query.filter(User.id.in_(student_ids)).all()
        
        # Get unique lecture dates (distinct dates with attendance records)
        lecture_dates = db.session.query(Attendance.date)\
            .filter(Attendance.course_id == course_id)\
            .distinct()\
            .all()
        
        total_lecture_days = len(lecture_dates)
        
        # Prepare student attendance summary
        students_summary = []
        
        for student in students:
            # Get all attendance records for the student and course
            attendance_records = Attendance.query.filter(
                Attendance.course_id == course_id,
                Attendance.student_id == student.id,
                Attendance.face_verified == True,
                Attendance.location_verified == True
            ).all()
            
            # Calculate attendance and absence counts
            attendance_count = len(attendance_records)
            absence_count = total_lecture_days - attendance_count
            
            # Calculate attendance percentage
            attendance_percentage = (attendance_count / total_lecture_days * 100) if total_lecture_days > 0 else 0
            
            # Add student data and attendance statistics
            student_data = {
                'student_id': student.id,
                'student_number': student.student_id,  # Student number
                'student_name': student.name,
                'total_lectures': total_lecture_days,
                'attendance_count': attendance_count,
                'absence_count': absence_count,
                'attendance_percentage': round(attendance_percentage, 2)
            }
            
            students_summary.append(student_data)
        
        # Calculate overall attendance statistics for the course
        total_students = len(students)
        
        return jsonify({
            'success': True,
            'course_id': course_id,
            'course_name': course.name,
            'course_code': course.code,
            'total_students': total_students,
            'total_lectures': total_lecture_days,
            'students': students_summary
        }), 200
        
    except Exception as e:
        logger.error(f"Error getting course attendance summary: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

# استيراد وظيفة إعادة تعيين كلمة المرور
try:
    from reset_password import reset_password
    # إضافة وظيفة إعادة تعيين كلمة المرور إلى التطبيق
    app.add_url_rule('/reset-password', view_func=reset_password, methods=['POST'])
    logger.info("Password reset endpoint registered successfully")
except ImportError as e:
    logger.error(f"Failed to import reset_password module: {e}")

if __name__ == '__main__':
    try:
        # Kill existing connections first
        kill_database_connections()
        
        # Initialize database (only creates tables if they don't exist)
        with app.app_context():
            db.create_all()
            logger.info("Database initialized successfully")

        # Add periodic cleanup to prevent database locking
        def cleanup_app():
            with app.app_context():
                try:
                    db.session.remove()
                    db.engine.dispose()
                except Exception as e:
                    logger.error(f"Error in periodic cleanup: {e}")

        # Run the application with periodic cleanup
        from apscheduler.schedulers.background import BackgroundScheduler
        scheduler = BackgroundScheduler()
        scheduler.add_job(func=cleanup_app, trigger="interval", seconds=60)
        scheduler.start()
        
        # Run the application
        app.run(host='0.0.0.0', debug=True, port=5000, threaded=True)

    except Exception as e:
        logger.error(f"Application error: {e}")
        raise
