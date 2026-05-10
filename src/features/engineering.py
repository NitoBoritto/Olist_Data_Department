"""
Feature engineering module for Olist ML pipelines.

Creates sklearn pipeline for sentiment feature transformation.
"""

from sklearn.feature_extraction.text import TfidfVectorizer


def build_sentiment_features() -> TfidfVectorizer:
    """
    Build feature engineering pipeline for sentiment analysis.
    
    Uses only TF-IDF vectorization for review_text.
    
    Returns:
        TfidfVectorizer instance
    """
    print("[ENGINEERING] Building sentiment feature pipeline...")
    
    vectorizer = TfidfVectorizer(
        ngram_range=(1, 2),
        min_df=7,
        max_df=0.8,
        max_features=2000,
    )
    
    print("[ENGINEERING] Sentiment features: TF-IDF vectorization only")
    
    return vectorizer
