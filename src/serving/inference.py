"""
Inference module for Olist ML serving.

Loads the trained sentiment model and provides prediction functions.
"""

import joblib
import sys
import asyncio
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Dict

# Add project root to path
project_root = Path(__file__).parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

# Load models at module import time (not per call)
_sentiment_model = None
_sentiment_label_mapping = None
_executor = ThreadPoolExecutor(max_workers=4)  # Thread pool for blocking model predictions


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


async def predict_sentiment(text: str) -> Dict:
    """
    Predict sentiment for review text.
    
    Args:
        text: Review text (Portuguese)
    
    Returns:
        Dictionary with sentiment and confidence
    """
    _load_models()
    
    if _sentiment_model is None:
        raise RuntimeError("Sentiment model not loaded. Ensure model exists at src/serving/models/sentiment_model/")
    
    # Get predictions (numeric) using executor to avoid blocking event loop
    try:
        # Wrap blocking model.predict() in run_in_executor
        loop = asyncio.get_event_loop()
        prediction_numeric = await loop.run_in_executor(
            _executor,
            lambda: _sentiment_model.predict([text])[0]
        )
        
        # Wrap blocking model.predict_proba() in run_in_executor
        probabilities = await loop.run_in_executor(
            _executor,
            lambda: _sentiment_model.predict_proba([text])[0]
        )
    except Exception as e:
        raise RuntimeError(f"Model prediction failed: {str(e)}")
    
    # Decode numeric prediction to sentiment label
    sentiment_label = _sentiment_label_mapping.get(int(prediction_numeric), "Unknown")
    confidence = float(max(probabilities))
    
    return {
        "sentiment": sentiment_label,
        "confidence": confidence,
    }
