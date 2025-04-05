from app import app, db, User, logger
from werkzeug.security import generate_password_hash
from flask import request, jsonify

@app.route('/reset-password', methods=['POST'])
def reset_password():
    """
    إعادة تعيين كلمة المرور للمستخدم عن طريق البريد الإلكتروني
    """
    try:
        data = request.json
        if not data or 'email' not in data or 'new_password' not in data:
            return jsonify({
                'success': False,
                'message': 'Email and new password are required'
            }), 400
            
        email = data.get('email')
        new_password = data.get('new_password')
        
        # البحث عن المستخدم
        user = User.query.filter_by(email=email).first()
        
        if not user:
            logger.warning(f'Password reset attempt failed: user not found for email {email}')
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404

        # تشفير كلمة المرور الجديدة باستخدام خوارزمية أكثر أمانًا
        hashed_password = generate_password_hash(new_password, method='pbkdf2:sha256')
        
        # تسجيل كلمة المرور المشفرة للتصحيح
        logger.debug(f"New password hash for {email}: {hashed_password}")
        
        # تحديث كلمة المرور
        user.password = hashed_password
        db.session.commit()
        
        logger.info(f'Password reset successful for user: {email}')
        return jsonify({
            'success': True,
            'message': 'Password reset successful'
        }), 200
        
    except Exception as e:
        logger.error(f'Error in reset_password: {str(e)}')
        db.session.rollback()
        return jsonify({
            'success': False,
            'message': 'An error occurred during password reset'
        }), 500

if __name__ == '__main__':
    # يمكن استخدام هذا الملف مباشرة لإعادة تعيين كلمة المرور لمستخدم معين
    with app.app_context():
        email = input("Enter user email: ")
        new_password = input("Enter new password: ")
        
        user = User.query.filter_by(email=email).first()
        if not user:
            print(f"User with email {email} not found")
        else:
            hashed_password = generate_password_hash(new_password, method='pbkdf2:sha256')
            user.password = hashed_password
            db.session.commit()
            print(f"Password reset successful for user: {email}")