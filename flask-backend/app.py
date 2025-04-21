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
from sqlalchemy.exc import IntegrityError

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# Agregar middleware para registrar todas las solicitudes
@app.before_request
def log_request_info():
    logger.info(f"Request from {request.remote_addr}: {request.method} {request.path}")
    logger.debug(f"Headers: {request.headers}")

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
    timestamp = db.Column(db.DateTime, default=datetime.datetime.now(datetime.timezone.utc))

# نموذج بيانات الحضور
class Attendance(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    course_id = db.Column(db.Integer, db.ForeignKey('course.id'), nullable=False)
    date = db.Column(db.Date, default=datetime.datetime.now(datetime.timezone.utc).date())
    timestamp = db.Column(db.DateTime, default=datetime.datetime.now(datetime.timezone.utc))
    face_verified = db.Column(db.Boolean, default=False)
    location_verified = db.Column(db.Boolean, default=False)

    # العلاقات
    student = db.relationship('User', backref='attendances')
    course = db.relationship('Course', backref='attendances')

# نموذج بيانات التعرف على الوجه
class FaceRecognition(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.datetime.now(datetime.timezone.utc))

# نموذج بيانات جلسات المحاضرات
class LectureSession(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    course_id = db.Column(db.Integer, db.ForeignKey('course.id'), nullable=False)
    date = db.Column(db.Date, default=datetime.datetime.now(datetime.timezone.utc).date(), nullable=False)
    # Ensure only one session per course per day
    __table_args__ = (db.UniqueConstraint('course_id', 'date'),)

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
        new_state = data.get('isAttendanceOpen', False)
        today_date = datetime.datetime.now().date()
        logger.info(f"Request to update attendance state for course {course_id} to {new_state} on {today_date}")

        # Use a transaction to ensure atomicity
        try:
            with db.session.begin_nested(): # Nested transaction for course update and potential session creation
                course = db.session.get(Course, course_id)

                if not course:
                    logger.warning(f"Course {course_id} not found during state update.")
                    # Abort the nested transaction
                    db.session.rollback()
                    return jsonify({
                        'success': False,
                        'message': 'Course not found'
                    }), 404

                lecture_session_created_or_found = False
                session_created_this_request = False

                if new_state:
                    # Explicitly check for an existing session for today
                    logger.info(f"Checking for existing lecture session for course {course_id} on {today_date}")
                    existing_session = LectureSession.query.filter_by(
                        course_id=course_id,
                        date=today_date
                    ).first()

                    if existing_session:
                        logger.info(f"Found existing lecture session (ID: {existing_session.id}) for course {course_id} on {today_date}. No new session needed.")
                        lecture_session_created_or_found = True
                    else:
                        # No session exists, attempt to create one
                        logger.info(f"No existing session found. Attempting to create lecture session for course {course_id} on {today_date}")
                        try:
                            new_session = LectureSession(course_id=course_id, date=today_date)
                            db.session.add(new_session)
                            db.session.flush() # Try to insert/get primary key/check constraints
                            lecture_session_created_or_found = True
                            session_created_this_request = True
                            logger.info(f"Successfully added new LectureSession (ID: {new_session.id} after flush) to session (pending commit).")
                        except IntegrityError as ie:
                            # This could happen in a rare race condition if another request created it between the check and the flush
                            db.session.rollback() # Rollback the nested transaction
                            logger.warning(f"IntegrityError creating session (likely race condition) for course {course_id} on {today_date}: {ie}. Nested transaction rolled back.")
                            # We might want to retry the whole operation or just return an error
                            # For simplicity now, we'll let the outer error handler catch it if needed after rollback.
                            # Or maybe just log and continue with course update? Let's try continuing.
                            lecture_session_created_or_found = False # It wasn't created successfully
                            session_created_this_request = False
                        except Exception as creation_error:
                            db.session.rollback() # Rollback the nested transaction
                            logger.error(f"Unexpected error creating lecture session for course {course_id} on {today_date}: {creation_error}")
                            raise # Re-raise to be caught by outer try-except

                # Always update the course state if we reach here without raising an error during session creation attempt
                logger.info(f"Updating course {course_id} state to {new_state}.")
                course.isAttendanceOpen = new_state

            # If the nested transaction wasn't rolled back, commit the changes
            db.session.commit()
            logger.info(f"Successfully committed state update for course {course_id} to {new_state}. Session created this request: {session_created_this_request}")

            return jsonify({
                'success': True,
                'message': 'Attendance state updated successfully',
                'isAttendanceOpen': new_state
            })

        except Exception as commit_error: # Catch errors during commit
            db.session.rollback()
            logger.error(f"Error during commit for course {course_id} state update: {commit_error}")
            # Decide if retry is appropriate here based on error type
            raise commit_error # Re-raise to be caught by the outer handler

    except Exception as e:
        # General error handling, potentially after retries fail or for unexpected issues
        logger.error(f"Critical error in update_attendance_state for course {course_id}: {e}")
        # Ensure rollback happens if a transaction was active
        if db.session.is_active:
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
                longitude=student_lon,
                timestamp=datetime.datetime.now(datetime.timezone.utc)
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
        logger.info(f"Received face_verified flag: {face_verified}") # Log received flag

        # Extract location verification status from sent data
        location_verified = data.get('location_verified', False)
        logger.info(f"Received location_verified flag: {location_verified}") # Log received flag

        # Check that both conditions are met
        if not face_verified or not location_verified:
            logger.warning(f"Verification failed: face_verified={face_verified}, location_verified={location_verified}")
            return jsonify({
                'success': False,
                'message': 'Both face and location verification are required to mark attendance'
            }), 400

        # Check first if student already has attendance for this course today
        now = datetime.datetime.now(datetime.timezone.utc)
        today = now.date()
        logger.info(f"Checking existing attendance for student {student_id}, course {course_id} on {today}")
        existing_attendance = Attendance.query.filter_by(
            student_id=student_id,
            course_id=course_id,
            date=today
        ).first()

        # Make sure we have a lecture session for today
        lecture_session = LectureSession.query.filter_by(course_id=course_id, date=today).first()
        if not lecture_session:
            # If there's no lecture session for today, create one
            try:
                new_session = LectureSession(course_id=course_id, date=today)
                db.session.add(new_session)
                db.session.commit()
                logger.info(f"Created new lecture session for course {course_id} on {today}")
            except Exception as e:
                logger.error(f"Error creating lecture session: {e}")
                # Continue even if we couldn't create the session

        if existing_attendance:
            logger.info("Attendance already recorded for today. Updating record.")
            # Update the existing attendance record to ensure it's marked as verified
            existing_attendance.face_verified = True
            existing_attendance.location_verified = True
            existing_attendance.timestamp = now  # Update timestamp
            db.session.commit()

            # Get course name for notification
            course = Course.query.get(course_id)
            course_name = course.name if course else "Unknown Course"

            logger.info(f"Updated attendance record for student {student_id}, course {course_id} on {today}")

            return jsonify({
                'success': True,
                'already_recorded': True,
                'message': 'Your attendance has been updated for this course today',
                'course_name': course_name
            }), 200

        # Check face recognition record in database
        face_record = FaceRecognition.query.filter_by(
            student_id=student_id
        ).order_by(FaceRecognition.timestamp.desc()).first()

        if not face_record:
            logger.warning("Face recognition record not found in DB.") # Log DB check fail
            return jsonify({
                'success': False,
                'message': 'Face verification not found in database'
            }), 400

        # Check if face recognition was done in the last 15 minutes
        # Convert naive datetime to aware datetime for comparison
        face_timestamp_aware = face_record.timestamp.replace(tzinfo=datetime.timezone.utc)
        face_time_diff = (now - face_timestamp_aware).total_seconds()
        logger.info(f"Time since last face verification: {face_time_diff} seconds") # Log time diff
        if face_time_diff > 15 * 60:  # 15 minutes
            logger.warning("Face verification record expired.") # Log expiration
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
            logger.warning("Location verification record not found in DB.") # Log DB check fail
            return jsonify({
                'success': False,
                'message': 'Location verification not found in database'
            }), 400

        # Check if location verification was done in the last 15 minutes
        # Convert naive datetime to aware datetime for comparison
        location_timestamp_aware = location_record.timestamp.replace(tzinfo=datetime.timezone.utc)
        location_time_diff = (now - location_timestamp_aware).total_seconds()
        logger.info(f"Time since last location verification: {location_time_diff} seconds") # Log time diff
        if location_time_diff > 15 * 60:  # 15 minutes
            logger.warning("Location verification record expired.") # Log expiration
            return jsonify({
                'success': False,
                'message': 'Location verification expired, please verify again'
            }), 400

        # Log verification attempt
        app.logger.info(f"All checks passed. Attempting to record attendance: student_id={student_id}, course_id={course_id}, face={face_verified}, location={location_verified}")

        # If all conditions are met, record attendance
        attendance = Attendance(
            student_id=student_id,
            course_id=course_id,
            face_verified=face_verified,
            location_verified=location_verified,
            date=today,  # Make sure we use the correct date
            timestamp=now
        )
        db.session.add(attendance)
        db.session.commit()

        # Log the attendance record
        logger.info(f"Recorded attendance for student {student_id}, course {course_id} on {today} at {now}")

        # Make sure we have a lecture session for today
        lecture_session = LectureSession.query.filter_by(course_id=course_id, date=today).first()
        if not lecture_session:
            # If there's no lecture session for today, create one
            try:
                new_session = LectureSession(course_id=course_id, date=today)
                db.session.add(new_session)
                db.session.commit()
                logger.info(f"Created new lecture session for course {course_id} on {today}")
            except Exception as e:
                logger.error(f"Error creating lecture session: {e}")
                # Continue even if we couldn't create the session

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
        now = datetime.datetime.now(datetime.timezone.utc)
        # Convert naive datetime to aware datetime for comparison
        face_timestamp_aware = face_record.timestamp.replace(tzinfo=datetime.timezone.utc)
        face_time_diff = (now - face_timestamp_aware).total_seconds()
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
        # Convert naive datetime to aware datetime for comparison
        location_timestamp_aware = location_record.timestamp.replace(tzinfo=datetime.timezone.utc)
        location_time_diff = (now - location_timestamp_aware).total_seconds()
        if location_time_diff > 15 * 60:  # 15 minutes
            return jsonify({
                'success': False,
                'message': 'Location verification expired, please verify again'
            }), 400

        # If all conditions are met, record attendance
        today = now.date()
        attendance = Attendance(
            student_id=student_id,
            course_id=course_id,
            face_verified=True,
            location_verified=True,
            date=today,  # Make sure we use the correct date
            timestamp=now
        )
        db.session.add(attendance)
        db.session.commit()

        # Make sure we have a lecture session for today
        lecture_session = LectureSession.query.filter_by(course_id=course_id, date=today).first()
        if not lecture_session:
            # If there's no lecture session for today, create one
            try:
                new_session = LectureSession(course_id=course_id, date=today)
                db.session.add(new_session)
                db.session.commit()
                logger.info(f"Created new lecture session for course {course_id} on {today}")
            except Exception as e:
                logger.error(f"Error creating lecture session: {e}")
                # Continue even if we couldn't create the session

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
            # Use timezone-aware datetime to avoid timezone issues
            filter_date = datetime.datetime.now(datetime.timezone.utc).date()

        # Log the date being used for filtering
        logger.info(f"Using date {filter_date} for attendance filtering")

        # Check if we need to create a lecture session for this date
        lecture_session = LectureSession.query.filter_by(course_id=course_id, date=filter_date).first()
        if not lecture_session:
            # If there's no lecture session for this date, create one
            try:
                new_session = LectureSession(course_id=course_id, date=filter_date)
                db.session.add(new_session)
                db.session.commit()
                logger.info(f"Created new lecture session for course {course_id} on {filter_date}")
            except Exception as e:
                logger.error(f"Error creating lecture session: {e}")
                # Continue even if we couldn't create the session

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
        # Make sure to get all attendance records for the day, regardless of verification status
        attendance_records = Attendance.query.filter(
            Attendance.course_id == course_id,
            Attendance.date == filter_date
        ).all()

        # Log the number of attendance records found
        logger.info(f"Found {len(attendance_records)} attendance records for course {course_id} on {filter_date}")

        # Only consider records where both face and location are verified
        # Group by student_id to ensure we only count each student once
        verified_records = {}
        for record in attendance_records:
            if record.face_verified and record.location_verified:
                # If we already have a record for this student, keep the earliest one
                if record.student_id not in verified_records or record.timestamp < verified_records[record.student_id].timestamp:
                    verified_records[record.student_id] = record

        # Convert back to list
        attendance_records = list(verified_records.values())

        # Log the number of verified records
        logger.info(f"Found {len(attendance_records)} verified attendance records for course {course_id} on {filter_date}")

        # Create a dictionary for easy lookup of attended students
        # Make sure we only count each student once (in case of multiple attendance records)
        attended_students = {}
        for record in attendance_records:
            # Only include verified records
            if record.face_verified and record.location_verified:
                # If we already have a record for this student, keep the earliest one
                if record.student_id not in attended_students or record.timestamp < attended_students[record.student_id].timestamp:
                    attended_students[record.student_id] = record

        # Log the number of students who attended
        logger.info(f"Found {len(attended_students)} students who attended course {course_id} on {filter_date}")

        # Make sure we have a lecture session for this date
        lecture_session = LectureSession.query.filter_by(course_id=course_id, date=filter_date).first()
        if not lecture_session and len(attended_students) > 0:
            # If we have attendance records but no lecture session, create one
            try:
                new_session = LectureSession(course_id=course_id, date=filter_date)
                db.session.add(new_session)
                db.session.commit()
                logger.info(f"Created new lecture session for course {course_id} on {filter_date}")
            except Exception as e:
                logger.error(f"Error creating lecture session: {e}")
                # Continue even if we couldn't create the session

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
            timestamp=datetime.datetime.now(datetime.timezone.utc)
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

        # Get unique lecture session dates for the course
        dates = db.session.query(LectureSession.date) \
            .filter(LectureSession.course_id == course_id) \
            .distinct() \
            .order_by(LectureSession.date.desc()) \
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

        # Get unique lecture session dates (distinct dates from LectureSession table)
        lecture_dates = db.session.query(LectureSession.date)\
            .filter(LectureSession.course_id == course_id)\
            .distinct()\
            .all()

        # Get unique attendance dates as well (in case there are attendances without lecture sessions)
        attendance_dates = db.session.query(db.func.distinct(Attendance.date))\
            .filter(Attendance.course_id == course_id)\
            .all()

        # Combine both sets of dates to get the total number of lecture days
        all_dates = set()
        for date_tuple in lecture_dates:
            all_dates.add(date_tuple[0])
        for date_tuple in attendance_dates:
            all_dates.add(date_tuple[0])

        total_lecture_days = len(all_dates)

        # If we still have zero lecture days but the course exists, set it to at least 1
        if total_lecture_days == 0:
            total_lecture_days = 1

        logger.info(f"Total lecture days for course {course_id}: {total_lecture_days}")

        # Get today's date to check if there's a lecture today (use UTC to avoid timezone issues)
        today = datetime.datetime.now(datetime.timezone.utc).date()
        logger.info(f"Today's date (UTC): {today}")

        if today not in all_dates:
            # Check if there are any attendance records for today
            today_attendance = db.session.query(Attendance)\
                .filter(Attendance.course_id == course_id, Attendance.date == today)\
                .first()
            if today_attendance:
                # If there are attendance records for today, add today to the lecture days
                all_dates.add(today)
                total_lecture_days = len(all_dates)
                logger.info(f"Added today to lecture days. New total: {total_lecture_days}")
            else:
                # Even if there are no attendance records, we should still add today as a lecture day
                # if the course is active
                all_dates.add(today)
                total_lecture_days = len(all_dates)
                logger.info(f"Added today as a lecture day even without attendance. New total: {total_lecture_days}")

        # Prepare student attendance summary
        students_summary = []

        for student in students:
            # Get all attendance records for the student and course
            # We'll count each unique date as one attendance
            attendance_records = Attendance.query.filter(
                Attendance.student_id == student.id,
                Attendance.course_id == course_id
            ).all()

            # Log all attendance records for debugging
            logger.info(f"Found {len(attendance_records)} total attendance records for student {student.id} in course {course_id}")
            for record in attendance_records:
                logger.info(f"Record: date={record.date}, face_verified={record.face_verified}, location_verified={record.location_verified}")

            # Filter for verified records only
            verified_records = [record for record in attendance_records if record.face_verified and record.location_verified]
            logger.info(f"After filtering, found {len(verified_records)} verified attendance records")

            # Use verified records for further processing
            attendance_records = verified_records

            # Get unique dates from attendance records
            attended_dates = set()
            for record in attendance_records:
                attended_dates.add(record.date)

            # This gives us the actual number of days the student attended
            attendance_count = len(attended_dates)

            # Log the attendance count for debugging
            logger.info(f"Student {student.id} ({student.name}) has attended {attendance_count} days for course {course_id}")
            logger.info(f"Attended dates: {attended_dates}")

            # Make sure we have at least one lecture session
            if total_lecture_days == 0 and attendance_count > 0:
                # If we have attendance records but no lecture sessions, use the attendance count as total
                total_lecture_days = attendance_count

            # Check if the student has attended today
            if today in attended_dates:
                logger.info(f"Student {student.id} ({student.name}) has attended today!")
            else:
                logger.info(f"Student {student.id} ({student.name}) has NOT attended today.")

            # Calculate absence count
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

            # Log the student data for debugging
            logger.info(f"Student data for {student.name}: {student_data}")

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

@app.route('/attendance/<lecture_id>', methods=['GET'])
def get_attendance(lecture_id):
    # جلب بيانات الحضور من قاعدة البيانات
    # إعادة استجابة JSON تحتوي على تفاصيل الطلاب، حالة الحضور، والعدد
    pass

# Función para obtener las interfaces de red disponibles
def get_network_interfaces():
    import socket

    interfaces = {}
    try:
        # Obtener el nombre del host
        hostname = socket.gethostname()
        # Obtener la dirección IP local
        local_ip = socket.gethostbyname(hostname)
        interfaces[hostname] = local_ip

        # Intentar obtener todas las direcciones IP
        try:
            all_ips = socket.getaddrinfo(hostname, None)
            for ip in all_ips:
                if ip[0] == socket.AF_INET:  # Solo IPv4
                    interfaces[f"{hostname}_{ip[4][0]}"] = ip[4][0]
        except Exception as e:
            logger.error(f"Error getting all IPs: {e}")
    except Exception as e:
        logger.error(f"Error getting network interfaces: {e}")

    return interfaces

if __name__ == '__main__':
    try:
        # Mostrar información de las interfaces de red
        interfaces = get_network_interfaces()
        logger.info(f"Available network interfaces: {interfaces}")

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
        logger.info("Starting server on 0.0.0.0:5000")
        app.run(host='0.0.0.0', debug=True, port=5000, threaded=True)

    except Exception as e:
        logger.error(f"Application error: {e}")
        raise
