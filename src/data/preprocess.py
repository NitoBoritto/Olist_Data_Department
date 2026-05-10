"""
Data preprocessing module for Olist ML pipelines.

Handles data cleaning and preparation for the sentiment pipeline.
"""

import pandas as pd
import re
from typing import Tuple, Dict
from sklearn.preprocessing import LabelEncoder


def preprocess_sentiment_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Preprocess sentiment analysis data.
    
    Maps review scores to sentiment labels (Positive/Negative),
    cleans text, and removes invalid records.
    
    Args:
        df: Raw data from extract_sentiment_data() with review_text and review_score
    
    Returns:
        Cleaned DataFrame with columns: review_text, sentiment (label: Positive/Negative)
    """
    df = df.copy()
    
    print("[PREPROCESS] Starting sentiment data cleaning...")
    initial_count = len(df)
    
    # Drop rows where review_text is null
    df = df.dropna(subset=["review_text"])
    
    # Map review_score to sentiment labels (BINARY classification)
    # score 1-3 -> Negative, score 4-5 -> Positive
    def score_to_sentiment(score):
        if score >= 4:
            return "Positive"
        else:  # score 1-2-3
            return "Negative"
    
    df["sentiment"] = df["review_score"].apply(score_to_sentiment)
    
    # Filter: keep only text with >= 3 words
    df["word_count"] = df["review_text"].str.split().str.len()
    df = df[df["word_count"] >= 3].copy()
    
    # Clean text: strip whitespace, lowercase, remove URLs and special characters
    df["review_text"] = df["review_text"].astype(str).str.strip().str.lower()
    
    # Remove URLs and non-portuguese characters (retain Portuguese diacritics)
    df["review_text"] = (
        df["review_text"]
        .apply(lambda x: re.sub(r"http\S+|www\S+", "", x))
        .apply(lambda x: re.sub(r"[^a-z0-9\s áéíóúãõçñ]", "", x))
        .apply(lambda x: re.sub(r"\s+", " ", x).strip())
    )
    
    # Filter: remove empty strings after cleaning
    df = df[df["review_text"].str.len() > 0].copy()
    
    # Select final columns
    df = df[["review_text", "sentiment"]].reset_index(drop=True)
    
    removed = initial_count - len(df)
    print(f"[PREPROCESS] Removed {removed} invalid records (kept {len(df)})")
    print(f"[PREPROCESS] Label distribution:\n{df['sentiment'].value_counts()}")
    
    return df


def encode_sentiment_labels(df: pd.DataFrame) -> Tuple[pd.DataFrame, Dict[int, str]]:
    """
    Encode sentiment labels to numeric values for model training.
    
    Args:
        df: DataFrame with 'sentiment' column containing string labels
    
    Returns:
        Tuple of (DataFrame with encoded sentiment, mapping dict {0: 'Negative', ...})
    """
    df = df.copy()
    le = LabelEncoder()
    df["sentiment_encoded"] = le.fit_transform(df["sentiment"])
    
    # Create mapping: {0: 'Negative', 1: 'Positive'} (sorted alphabetically - binary classification)
    label_mapping = {i: label for i, label in enumerate(le.classes_)}
    
    print(f"[PREPROCESS] Sentiment label mapping: {label_mapping}")
    
    return df, label_mapping
