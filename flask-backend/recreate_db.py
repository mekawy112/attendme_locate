from app import app, db

# Use application context to ensure proper database operations
with app.app_context():
    # Drop all existing tables
    db.drop_all()
    
    # Create all tables with the updated schema
    db.create_all()
    
    print('Database tables recreated successfully!')