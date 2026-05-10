"""
Feature engineering module for Olist ML pipelines.

Creates sklearn pipelines for sentiment feature transformation.
"""

from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import FunctionTransformer, OneHotEncoder, RobustScaler
from sklearn.feature_extraction.text import TfidfVectorizer


# Module-level functions for pickling (cannot use lambdas in ColumnTransformer)
def _encode_bool_flags(X):
    """Convert boolean flags (as strings) to binary integers."""
    return (X.astype(str) == "True").astype(int)


def build_sentiment_features() -> ColumnTransformer:
    """
    Build feature engineering pipeline for sentiment analysis.
    
    Matches the notebook pattern:
    - One-hot encode primary_payment_type and order_status
    - Robust-scale delivery_days_actual and total_payment
    - TF-IDF vectorize review_text
    - Encode boolean flags is_late_delivery and is_invalid_payment
    
    Returns:
        ColumnTransformer instance
    """
    print("[ENGINEERING] Building sentiment feature pipeline...")
    
    bool_encoder = FunctionTransformer(
        func=_encode_bool_flags,
        feature_names_out="one-to-one",
    )
    
    preprocessor = ColumnTransformer(
        transformers=[
            ("ohe", OneHotEncoder(drop="first", sparse_output=False, handle_unknown='ignore'), ["primary_payment_type", "order_status"]),
            ("scaler", RobustScaler(), ["delivery_days_actual", "total_payment"]),
            ("vectorizer", TfidfVectorizer(ngram_range=(1, 2), min_df=7, max_df=0.8), "review_text"),
            ("bools", bool_encoder, ["is_late_delivery", "is_invalid_payment"]),
        ],
        remainder="passthrough",
    )
    
    print("[ENGINEERING] Sentiment features: OHE + RobustScaler + TF-IDF + bool encoding")
    
    return preprocessor
