"""
Pydantic schema definitions for Olist FastAPI application.

Handles request validation and response formatting.
"""

from pydantic import BaseModel, Field, validator
from typing import Literal


class SentimentRequest(BaseModel):
    """Request model for sentiment analysis prediction."""
    
    text: str = Field(..., min_length=10, max_length=1000, description="Review text to analyze")
    
    @validator("text")
    def validate_text_length(cls, v):
        """Validate that text is not empty."""
        if not v or len(v.strip()) == 0:
            raise ValueError("Text cannot be empty")
        return v


class SentimentResponse(BaseModel):
    """Response model for sentiment analysis prediction."""
    
    sentiment: Literal["Positive", "Negative"]
    confidence: float
    delivery_context: str = "Sentiment analysis from review text"
    category: str = "General"
