"""
Data extraction module for Olist ML pipelines.

Handles extraction of data from Azure SQL for sentiment analysis.
"""

import pandas as pd
from sqlalchemy import text
from typing import Optional
import sys
from pathlib import Path
from src.warehouse.engine import get_db_engine

# Add project root to path
project_root = Path(__file__).parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))


def extract_sentiment_data(
    engine=None,
    input_csv: Optional[str] = None,
) -> pd.DataFrame:
    """
    Extract data for sentiment analysis pipeline.
    
    Args:
        engine: SQLAlchemy engine instance. If None, creates new connection.
        input_csv: Optional local CSV file path to override database extraction.
    
    Returns:
        DataFrame with columns: customer_unique_id, review_score, review_text,
        delivery_days_actual, order_status
    
    Raises:
        FileNotFoundError: If input_csv is provided but file doesn't exist.
        ValueError: If database connection fails and no input_csv provided.
    """
    if input_csv:
        if not Path(input_csv).exists():
            raise FileNotFoundError(f"Input CSV file not found: {input_csv}")
        print(f"[EXTRACT] Loading sentiment data from {input_csv}")
        df = pd.read_csv(input_csv)
        return df
    
    if engine is None:
        engine = get_db_engine()
    
    query = """
    SELECT 
        customer_unique_id,
        review_score,
        primary_payment_type,
        order_status,
        delivery_days_actual,
        total_payment,
        review_text,
        is_late_delivery,
        is_invalid_payment
    FROM Gold.Fact_Orders
    WHERE review_text IS NOT NULL
    """
    
    print("[EXTRACT] Pulling sentiment data from Gold.Fact_Orders...")
    df = pd.read_sql(text(query), engine)
    print(f"[EXTRACT] Extracted {len(df)} records for sentiment analysis")
    
    return df