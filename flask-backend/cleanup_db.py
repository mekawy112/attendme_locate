import sqlite3
import os
import time
import sys
import signal

def cleanup_database():
    db_path = 'database.db'
    max_retries = 5
    retry_delay = 2  # seconds
    
    if not os.path.exists(db_path):
        print("Database file not found")
        return
        
    print("Starting database cleanup...")
    
    for attempt in range(max_retries):
        try:
            # Try to get exclusive access to database
            conn = sqlite3.connect(db_path, timeout=30, isolation_level='EXCLUSIVE')
            
            # Configure database settings
            conn.execute('PRAGMA journal_mode=DELETE;')  # Disable WAL mode temporarily
            conn.execute('PRAGMA busy_timeout=30000;')   # 30 second timeout
            conn.execute('PRAGMA synchronous=OFF;')      # Temporarily disable synchronous mode
            
            print(f"Attempt {attempt + 1}: Connected to database")
            
            # Force checkpoint any existing WAL files
            conn.execute('PRAGMA wal_checkpoint(TRUNCATE);')
            
            # Vacuum the database
            print("Vacuuming database...")
            conn.execute('VACUUM;')
            
            # Reset database settings
            conn.execute('PRAGMA synchronous=NORMAL;')
            conn.execute('PRAGMA journal_mode=WAL;')
            
            conn.commit()
            print("Database cleanup successful!")
            return True
            
        except sqlite3.OperationalError as e:
            print(f"Attempt {attempt + 1}/{max_retries}: {str(e)}")
            if 'database is locked' in str(e):
                time.sleep(retry_delay)
                continue
            else:
                print(f"Error: {str(e)}")
                break
                
        except Exception as e:
            print(f"Unexpected error: {str(e)}")
            break
            
        finally:
            if 'conn' in locals():
                try:
                    conn.close()
                except:
                    pass
    
    print("Failed to cleanup database after maximum retries")
    return False

if __name__ == '__main__':
    print("Database Cleanup Utility")
    print("-----------------------")
    print("Please ensure the Flask server is stopped before continuing.")
    input("Press Enter to continue or Ctrl+C to cancel...")
    
    try:
        
        success = cleanup_database()
        if success:
            print("\nCleanup completed successfully.")
        else:
            print("\nCleanup failed. Please try again after stopping all database connections.")
            sys.exit(1)
    except KeyboardInterrupt:
        print("\nCleanup cancelled by user.")
        sys.exit(0)