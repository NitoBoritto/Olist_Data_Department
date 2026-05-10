"""
FastAPI application for Olist ML model serving.

Provides REST endpoints for sentiment analysis.
"""

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from src.app.schema import (
    SentimentRequest,
    SentimentResponse,
)
from src.serving.inference import predict_sentiment, _load_models

# Initialize FastAPI app
app = FastAPI(
    title="Olist ML API",
    description="End-to-end ML pipeline for sentiment analysis",
    version="1.0.0",
)

# Add CORS middleware (allow all origins for development)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Eager load models on startup
@app.on_event("startup")
async def load_models_on_startup():
    """Load ML models on application startup to avoid delays on first prediction."""
    try:
        _load_models()
        print("[STARTUP] Sentiment model loaded successfully")
    except Exception as e:
        print(f"[STARTUP] Warning: Failed to load sentiment model: {e}")


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "ok",
        "models": ["sentiment"],
    }


@app.post("/api/predict/sentiment", response_model=SentimentResponse)
async def predict_sentiment_endpoint(request: SentimentRequest) -> SentimentResponse:
    """
    Predict sentiment for a review.
    
    Returns sentiment label, confidence score, and delivery context.
    """
    try:
        result = predict_sentiment(
            text=request.text,
            delivery_status=request.delivery_status,
            category=request.category,
            order_status=request.order_status,
            primary_payment_type=request.primary_payment_type,
            total_payment=request.total_payment,
            delivery_days_actual=request.delivery_days_actual,
            is_late_delivery=request.is_late_delivery,
            is_invalid_payment=request.is_invalid_payment,
        )
        
        return SentimentResponse(
            sentiment=result["sentiment"],
            confidence=result["confidence"],
            delivery_context=result["delivery_context"],
            category=result["category"],
        )
    except ValueError as e:
        # Validation error
        return JSONResponse(
            status_code=422,
            content={"detail": str(e)},
        )
    except Exception as e:
        # Server error
        import traceback
        print(f"[ERROR] Prediction failed: {e}")
        print(traceback.format_exc())
        return JSONResponse(
            status_code=500,
            content={"detail": f"Prediction failed: {str(e)}"},
        )


@app.post("/api/farghaly/chat")
async def farghaly_chat(request: dict):
    """
    Proxy endpoint to Anthropic API for chat functionality.
    
    Pass-through endpoint - no processing here.
    
    Body: {"message": str, "history": list}
    """
    try:
        import anthropic
        
        client = anthropic.Anthropic()
        
        message = request.get("message", "")
        history = request.get("history", [])
        
        # Build messages for API
        messages = history + [{"role": "user", "content": message}]
        
        response = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1024,
            messages=messages,
        )
        
        assistant_message = response.content[0].text
        
        return {
            "response": assistant_message,
            "history": messages + [{"role": "assistant", "content": assistant_message}],
        }
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"detail": f"Chat failed: {str(e)}"},
        )


# Mount static frontend
app.mount(
    "/",
    StaticFiles(directory=str(project_root / "src" / "app"), html=True),
    name="frontend",
)


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
    )
