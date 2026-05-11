import os
from time import sleep
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

def get_db_engine(max_retries=3, initial_delay_seconds=2.0):
    azure_string = os.getenv("AZURE_SQL_STRING")
    
    if not azure_string:
        raise ValueError(
            "AZURE_SQL_STRING must be set in environment variables."
        )
    
    delay_seconds = initial_delay_seconds
    last_error = None

    try:
        for attempt in range(1, max_retries + 1):
            try:
                engine = create_engine(
                    azure_string,
                    pool_pre_ping=True,
                    pool_recycle=300,
                    pool_timeout=30,
                )
                with engine.connect() as conn:
                    conn.exec_driver_sql("SELECT 1")
                print("Database connection successful!")
                return engine
            except Exception as e:
                last_error = e
                print(f"Database connection attempt {attempt} failed: {e}")
                if attempt < max_retries:
                    sleep(delay_seconds)
                    delay_seconds *= 2
        print(f"Error creating database engine after {max_retries} attempts: {last_error}")
        raise last_error
    except Exception as e:
        print(f"Error creating database engine: {e}")
        raise