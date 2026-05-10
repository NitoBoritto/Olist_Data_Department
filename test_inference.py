"""Quick test of the inference pipeline."""
import asyncio
from src.serving.inference import predict_sentiment

# Test basic prediction
async def test_prediction():
    try:
        result = await predict_sentiment(
            text="Produto excelente com entrega rápida"
        )
        print("[OK] Prediction successful")
        print(f"Sentiment: {result['sentiment']}")
        print(f"Confidence: {result['confidence']:.4f}")
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_prediction())
