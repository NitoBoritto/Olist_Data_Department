import os
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

def get_db_engine():
    azure_string = os.getenv("AZURE_SQL_STRING")
    
    if not azure_string:
        raise ValueError(
            "AZURE_SQL_STRING must be set in environment variables."
        )
    
    try:
        engine = create_engine(azure_string)
        # Test the connection
        with engine.connect() as conn:
            print("Database connection successful!")
        return engine
    except Exception as e:
        print(f"Error creating database engine: {e}")
        raise