"""
Model training module for Olist ML pipelines.

Handles training of the sentiment classifier.
"""

import pandas as pd
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder
from sklearn.linear_model import LogisticRegression
from typing import Tuple, Dict, Any
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))


def train_sentiment_model(
    X_train: pd.DataFrame,
    y_train: pd.Series,
    best_params: Dict[str, Any],
    random_state: int = 30,
) -> Tuple[Pipeline, Dict[int, str]]:
    """
    Train Logistic Regression model for sentiment classification (best-performing model).
    
    Args:
        X_train: Training features
        y_train: Training labels (numeric: 0=Negative, 1=Positive)
        best_params: Hyperparameters from tuning
        random_state: Random state for reproducibility
    
    Returns:
        Tuple of (trained pipeline, label_mapping dict)
    """
    print("[TRAIN] Starting sentiment model training...")
    from src.features.engineering import build_sentiment_features
    
    if y_train.dtype == 'object':
        le = LabelEncoder()
        y_train_encoded = le.fit_transform(y_train)
        label_mapping = {i: label for i, label in enumerate(le.classes_)}
        print(f"[TRAIN] Encoded labels: {label_mapping}")
    else:
        y_train_encoded = y_train
        label_mapping = {0: 'Negative', 1: 'Positive'}
    
    feature_transformer = build_sentiment_features()
    classifier = LogisticRegression(random_state=random_state, max_iter=1000)
    pipeline = Pipeline([
        ("preprocessor", feature_transformer),
        ("classifier", classifier),
    ])
    
    # Apply tuned hyperparameters (filter out metadata keys)
    params = {k: v for k, v in best_params.items() if k not in ["model_type", "best_score"]}
    pipeline.set_params(**params)
    
    print("[TRAIN] Fitting sentiment pipeline with Logistic Regression...")
    pipeline.fit(X_train, y_train_encoded)
    
    print("[TRAIN] Sentiment model trained successfully")
    print("[TRAIN] Model: LogisticRegression")
    print(f"[TRAIN] Model params: {params}")
    
    return pipeline, label_mapping
