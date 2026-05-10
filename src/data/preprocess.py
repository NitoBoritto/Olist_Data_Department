"""
Data preprocessing module for Olist ML pipelines.

Handles data cleaning, validation, and preparation for the sentiment pipeline.
"""

import pandas as pd
import re
from typing import Tuple, Dict
from sklearn.preprocessing import LabelEncoder

# Optional spaCy-based text refinement (improves tokenization/lemmatization)
try:
    import spacy
    _spacy_available = True
    try:
        _nlp = spacy.load("pt_core_news_sm")
    except Exception:
        try:
            _nlp = spacy.load("pt_core_news_lg")
        except Exception:
            _nlp = None
            _spacy_available = False
except Exception:
    _spacy_available = False
    _nlp = None


def preprocess_sentiment_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Preprocess sentiment analysis data.
    
    Maps review scores to sentiment labels (Positive/Neutral/Negative),
    cleans text, and removes invalid records.
    
    Args:
        df: Raw data from extract_sentiment_data()
    
    Returns:
        Cleaned DataFrame with columns: review_text, delivery_days_actual,
        sentiment (label: Positive/Neutral/Negative)
    """
    df = df.copy()

    if "review_text" not in df.columns and "review_comment_message" in df.columns:
        df = df.rename(columns={"review_comment_message": "review_text"})

    defaults = {
        "primary_payment_type": "unknown",
        "order_status": "unknown",
        "total_payment": 0.0,
        "is_late_delivery": False,
        "is_invalid_payment": False,
    }
    for column_name, default_value in defaults.items():
        if column_name not in df.columns:
            df[column_name] = default_value
    
    print("[PREPROCESS] Starting sentiment data cleaning...")
    initial_count = len(df)
    
    # Map review_score to sentiment labels (BINARY classification like notebook)
    # score 1-3 -> Negative, score 4-5 -> Positive
    def score_to_sentiment(score):
        if score >= 4:
            return "Positive"
        else:  # score 1-2-3
            return "Negative"
    
    df["sentiment"] = df["review_score"].apply(score_to_sentiment)
    
    # Drop rows where review_text is null
    df = df.dropna(subset=["review_text"])
    
    # Ensure numeric fields are numeric and fill NaNs
    df["delivery_days_actual"] = pd.to_numeric(df["delivery_days_actual"], errors="coerce")
    df["total_payment"] = pd.to_numeric(df["total_payment"], errors="coerce")
    df = df.dropna(subset=["delivery_days_actual", "total_payment"])
    
    # Filter: keep only text with >= 3 words
    df["word_count"] = df["review_text"].str.split().str.len()
    df = df[df["word_count"] >= 3].copy()
    
    # Clean text: strip whitespace, lowercase, remove URLs and special characters
    df["review_text"] = df["review_text"].astype(str).str.strip().str.lower()

    # If spaCy is available, apply a lightweight refinement similar to the notebook
    def _refine_with_spacy(text: str) -> str:
        if not _spacy_available or _nlp is None:
            return text
        doc = _nlp(text)
        important_tags = {"NOUN", "ADJ", "VERB", "ADV"}
        tokens = [
            token.lemma_.lower()
            for token in doc
            if (not token.is_stop or token.text.lower() == "não")
            and token.pos_ in important_tags
            and len(token.text) > 2
        ]
        return " ".join(tokens)

    # Remove URLs and non-portuguese characters (retain Portuguese diacritics)
    df["review_text"] = (
        df["review_text"]
        .apply(lambda x: re.sub(r"http\S+|www\S+", "", x))
        .apply(lambda x: re.sub(r"[^a-z0-9\s áéíóúãõçñ]", "", x))
        .apply(lambda x: re.sub(r"\s+", " ", x).strip())
    )

    # Apply spaCy refinement if available (fall back to cleaned text otherwise)
    if _spacy_available and _nlp is not None:
        df["review_text"] = df["review_text"].apply(_refine_with_spacy)
    
    # Filter: remove empty strings after cleaning
    df = df[df["review_text"].str.len() > 0].copy()
    
    # Select final columns
    df = df[[
        "review_text",
        "primary_payment_type",
        "order_status",
        "delivery_days_actual",
        "total_payment",
        "is_late_delivery",
        "is_invalid_payment",
        "sentiment",
    ]].reset_index(drop=True)
    
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
