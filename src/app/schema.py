"""
Pydantic schema definitions for Olist FastAPI application.

Handles request validation and response formatting.
"""

from pydantic import BaseModel, Field, validator
from typing import Literal


class SentimentRequest(BaseModel):
    """Request model for sentiment analysis prediction."""
    
    text: str = Field(..., min_length=10, max_length=1000, description="Review text to analyze (Portuguese only)")
    
    @validator("text")
    def validate_text_length(cls, v):
        """Validate that text is not empty."""
        if not v or len(v.strip()) == 0:
            raise ValueError("Text cannot be empty")
        return v
    
    @validator("text")
    def validate_portuguese_language(cls, v):
        """Validate that the text is in Portuguese language."""
        try:
            from langdetect import detect, LangDetectException
            
            # Try to detect language
            try:
                detected_lang = detect(v)
                if detected_lang != "pt":
                    raise ValueError(
                        f"Text must be in Portuguese. Detected language: {detected_lang}. "
                        "Please provide a review in Portuguese."
                    )
            except LangDetectException:
                # If detection fails due to text being too short or ambiguous,
                # allow it to proceed (will be caught by model if truly invalid)
                if len(v.strip()) < 5:
                    raise ValueError(
                        "Text is too short to detect language. Please provide at least 5 characters in Portuguese."
                    )
        except ImportError:
            raise RuntimeError(
                "Language detection library not available. "
                "Please install langdetect: pip install langdetect"
            )
        
        return v


class SentimentResponse(BaseModel):
    """Response model for sentiment analysis prediction."""
    
    sentiment: Literal["Positive", "Negative"]
    confidence: float
    delivery_context: str = "Sentiment analysis from review text"
    category: str = "General"
