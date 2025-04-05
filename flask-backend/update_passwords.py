from app import app, db, User, logger
from werkzeug.security import generate_password_hash

"""
This script updates existing user passwords to properly hashed versions.
It should be run once after updating the password field length in the User model.
"""

def update_user_passwords():
    with app.app_context():
        try:
            # Get all users
            users = User.query.all()
            updated_count = 0
            
            for user in users:
                # Check if the password is not already hashed
                # Hashed passwords typically start with 'pbkdf2:sha256:' or similar
                if not user.password.startswith('pbkdf2:sha256:'):
                    # Store the original password
                    original_password = user.password
                    
                    # Hash the password
                    hashed_password = generate_password_hash(original_password, method='pbkdf2:sha256')
                    
                    # Update the user's password
                    user.password = hashed_password
                    updated_count += 1
                    
                    logger.info(f"Updated password for user: {user.email}")
            
            # Commit all changes
            if updated_count > 0:
                db.session.commit()
                logger.info(f"Successfully updated {updated_count} user passwords")
            else:
                logger.info("No passwords needed updating")
                
            return updated_count
        except Exception as e:
            logger.error(f"Error updating passwords: {e}")
            db.session.rollback()
            return -1


if __name__ == '__main__':
    print("Starting password update process...")
    count = update_user_passwords()
    if count >= 0:
        print(f"Successfully updated {count} user passwords")
    else:
        print("Failed to update passwords. Check the logs for details.")