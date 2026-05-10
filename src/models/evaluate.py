"""
Model evaluation module for Olist ML pipelines.

Computes metrics and logs results to MLflow.
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import mlflow
from sklearn.metrics import (
    f1_score,
    accuracy_score,
    precision_score,
    recall_score,
    confusion_matrix,
    classification_report,
)
import tempfile
import os
from typing import Dict, Optional
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))


def evaluate_sentiment_model(
    model,
    X_test: pd.DataFrame,
    y_test: pd.Series,
    label_mapping: Optional[Dict[int, str]] = None,
) -> Dict[str, float]:
    """
    Evaluate sentiment classifier and log metrics to MLflow.
    
    Args:
        model: Trained sentiment classifier pipeline
        X_test: Test features
        y_test: Test labels (numeric: 0=Negative, 1=Positive)
        label_mapping: Dict mapping numeric labels to names {0: 'Negative', 1: 'Positive'}
    
    Returns:
        Dictionary of evaluation metrics
    """
    if label_mapping is None:
        label_mapping = {0: "Negative", 1: "Positive"}
    
    labels = [label_mapping[i] for i in sorted(label_mapping.keys())]
    
    print("[EVALUATE] Computing sentiment model metrics...")
    
    # Make predictions
    y_pred = model.predict(X_test)
    
    # Compute metrics
    metrics = {
        "weighted_f1": f1_score(y_test, y_pred, average="weighted", zero_division=0),
        "macro_f1": f1_score(y_test, y_pred, average="macro", zero_division=0),
        "accuracy": accuracy_score(y_test, y_pred),
    }
    
    # Per-class metrics
    for class_id in sorted(label_mapping.keys()):
        label_name = label_mapping[class_id]
        y_test_binary = (y_test == class_id).astype(int)
        y_pred_binary = (y_pred == class_id).astype(int)
        
        metrics[f"{label_name}_precision"] = precision_score(
            y_test_binary, y_pred_binary, zero_division=0
        )
        metrics[f"{label_name}_recall"] = recall_score(
            y_test_binary, y_pred_binary, zero_division=0
        )
        metrics[f"{label_name}_f1"] = f1_score(
            y_test_binary, y_pred_binary, zero_division=0
        )
    
    # Log to MLflow
    for key, value in metrics.items():
        mlflow.log_metric(key, value)
    
    # Log confusion matrix as artifact
    cm = confusion_matrix(y_test, y_pred, labels=sorted(label_mapping.keys()))
    plt.figure(figsize=(10, 8))
    sns.heatmap(
        cm,
        annot=True,
        fmt="d",
        cmap="Blues",
        xticklabels=labels,
        yticklabels=labels,
    )
    plt.title("Sentiment Classification Confusion Matrix")
    plt.ylabel("True Label")
    plt.xlabel("Predicted Label")
    
    # Save to temporary file and log as artifact
    with tempfile.TemporaryDirectory() as tmpdir:
        cm_path = os.path.join(tmpdir, "confusion_matrix.png")
        plt.savefig(cm_path, bbox_inches="tight", dpi=100)
        mlflow.log_artifact(cm_path, artifact_path="artifacts")
    plt.close()
    
    # Log classification report
    report = classification_report(y_test, y_pred, target_names=labels, digits=3)
    mlflow.log_text(report, "classification_report.txt")
    
    print("\n[EVALUATE] Classification Report:")
    print(report)
    
    print("[EVALUATE] Metrics logged to MLflow:")
    for key, value in sorted(metrics.items()):
        print(f"  {key}: {value:.4f}")
    
    return metrics
