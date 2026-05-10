"""
Inference module for Olist ML serving.

Loads the trained sentiment model and provides prediction functions.
"""

import pandas as pd
import joblib
import sys
from pathlib import Path
from typing import Dict

# Add project root to path
project_root = Path(__file__).parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

# Load models at module import time (not per call)
_sentiment_model = None
_sentiment_label_mapping = None


def _load_models():
    """Load pre-trained models from disk."""
    global _sentiment_model, _sentiment_label_mapping
    
    if _sentiment_model is None:
        model_dir = project_root / "src" / "serving" / "models"
        sentiment_path = model_dir / "sentiment_model" / "sentiment_pipeline.pkl"
        label_mapping_path = model_dir / "sentiment_model" / "label_mapping.json"
        
        if sentiment_path.exists():
            _sentiment_model = joblib.load(sentiment_path)
        
        if label_mapping_path.exists():
            import json
            with open(label_mapping_path) as f:
                # Convert string keys to int
                mapping = json.load(f)
                _sentiment_label_mapping = {int(k): v for k, v in mapping.items()}
        else:
            # Default mapping
            _sentiment_label_mapping = {0: "Negative", 1: "Positive"}


def predict_sentiment(
    text: str,
    delivery_status: str,
    category: str,
    order_status: str = "delivered",
    primary_payment_type: str = "credit_card",
    total_payment: float = 0.0,
    delivery_days_actual: float = 0.0,
    is_late_delivery: bool = False,
    is_invalid_payment: bool = False,
) -> Dict:
    """
    Predict sentiment for review text.
    
    Args:
        text: Review text (Portuguese)
        delivery_status: 'on_time' or 'late'
        category: Product category
        order_status: Order status (delivered, shipped, etc.)
        primary_payment_type: Payment method used
        total_payment: Total payment amount
        delivery_days_actual: Actual delivery days
        is_late_delivery: Whether delivery was late
        is_invalid_payment: Whether payment was invalid
    
    Returns:
        Dictionary with sentiment, confidence, delivery_context, category
    """
    _load_models()
    
    if _sentiment_model is None:
        raise RuntimeError("Sentiment model not loaded. Ensure model exists at src/serving/models/sentiment_model/")
    
    # Prepare input with all features the model was trained on
    df = pd.DataFrame({
        "review_text": [text],
        "primary_payment_type": [primary_payment_type],
        "order_status": [order_status],
        "delivery_days_actual": [float(delivery_days_actual)],
        "total_payment": [float(total_payment)],
        "is_late_delivery": [bool(is_late_delivery)],
        "is_invalid_payment": [bool(is_invalid_payment)],
    })
    
    # Get predictions (numeric)
    try:
        prediction_numeric = _sentiment_model.predict(df)[0]
        probabilities = _sentiment_model.predict_proba(df)[0]
    except Exception as e:
        raise RuntimeError(f"Model prediction failed: {str(e)}")
    
    # Decode numeric prediction to sentiment label
    sentiment_label = _sentiment_label_mapping.get(int(prediction_numeric), "Unknown")
    
    confidence = float(max(probabilities))
    
    delivery_context = f"Status: {delivery_status}"
    
    return {
        "sentiment": sentiment_label,
        "confidence": confidence,
        "delivery_context": delivery_context,
        "category": category,
    }
