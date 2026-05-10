"""
Pydantic schema definitions for Olist FastAPI application.

Handles request validation and response formatting.
"""

from pydantic import BaseModel, Field, validator
from typing import Literal


class SentimentRequest(BaseModel):
    """Request model for sentiment analysis prediction."""
    
    text: str = Field(..., min_length=10, max_length=1000)
    delivery_status: Literal["on_time", "late"]
    category: str = Field(..., min_length=2)
    order_status: str = Field(default="delivered")  # trained on: 'delivered', 'canceled'
    primary_payment_type: str = Field(default="credit card")  # trained on: 'credit card', 'boleto', 'debit card', 'voucher'
    total_payment: float = Field(default=0.0, ge=0.0)
    delivery_days_actual: float = Field(default=0.0, ge=0.0)
    is_late_delivery: bool = Field(default=False)
    is_invalid_payment: bool = Field(default=False)
    
    @validator("text")
    def validate_text_length(cls, v):
        """Basic text validation - skip language detection for performance."""
        if not v or len(v.strip()) == 0:
            raise ValueError("Text cannot be empty")
        return v


class SentimentResponse(BaseModel):
    """Response model for sentiment analysis prediction."""
    
    sentiment: Literal["Positive", "Negative"]
    confidence: float
    delivery_context: str
    category: str
