"""
Hyperparameter tuning module for Olist ML pipelines.

Uses Optuna for Bayesian optimization of model hyperparameters.
"""

import pandas as pd
import numpy as np
import optuna
from optuna.samplers import TPESampler
from sklearn.model_selection import StratifiedKFold, cross_val_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder
from sklearn.linear_model import LogisticRegression
from sklearn.base import clone
from typing import Dict, Any
import sys
from pathlib import Path
import warnings

warnings.filterwarnings("ignore")

# Add project root to path
project_root = Path(__file__).parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

# Suppress Optuna logging
optuna.logging.set_verbosity(optuna.logging.WARNING)


def tune_sentiment_classifier(
    X_train: pd.Series,
    y_train: pd.Series,
    n_trials: int = 50,
    random_state: int = 30,
) -> Dict[str, Any]:
    """
    Tune Logistic Regression for sentiment classification.
    
    Args:
        X_train: Series of review_text strings
        y_train: Series of sentiment labels (Positive/Negative)
        n_trials: Number of tuning trials
        random_state: Random state for reproducibility
    
    Returns:
        Dictionary with optimized hyperparameters
    """
    print(f"[TUNE] Starting Logistic Regression sentiment tuning ({n_trials} trials)...")
    
    from src.features.engineering import build_sentiment_features

    if y_train.dtype == "object":
        le = LabelEncoder()
        y_train_encoded = le.fit_transform(y_train)
    else:
        y_train_encoded = y_train
    
    vectorizer = build_sentiment_features()
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=random_state)

    def objective(trial):
        lgr_params = {
            "classifier__C": trial.suggest_float("classifier__C", 0.01, 10.0, log=True),
            "classifier__max_iter": trial.suggest_int("classifier__max_iter", 1000, 3000),
            "classifier__class_weight": trial.suggest_categorical("classifier__class_weight", ["balanced", None]),
        }

        pipeline = Pipeline([
            ("vectorizer", clone(vectorizer)),
            ("classifier", LogisticRegression(random_state=random_state)),
        ])
        pipeline.set_params(**lgr_params)

        scores = cross_val_score(
            pipeline,
            X_train,
            y_train_encoded,
            cv=skf,
            scoring="f1_macro",
            n_jobs=1,
            error_score=0.0,
        )
        if np.isnan(scores).any():
            return 0.0
        return float(scores.mean() - (scores.std() * 0.5))

    sampler = TPESampler(seed=random_state)
    study = optuna.create_study(direction="maximize", sampler=sampler)
    study.optimize(objective, n_trials=n_trials, show_progress_bar=False)

    best = {"model_type": "logistic_regression", "best_score": float(study.best_value)}
    best.update(study.best_params)

    print("[TUNE] Logistic Regression sentiment tuning complete")
    print(f"[TUNE] Best score: {best['best_score']:.4f}")
    print(f"[TUNE] Best params: {best}")

    return best
