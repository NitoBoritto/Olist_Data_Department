"""Test FastAPI endpoint directly."""
import asyncio
from src.app.main import predict_sentiment_endpoint
from src.app.schema import SentimentRequest

async def test_api():
    try:
        request = SentimentRequest(
            text="Produto excelente com entrega rápida",
            delivery_status="on_time",
            category="Eletronicos",
            order_status="delivered",
            primary_payment_type="credit_card",
            total_payment=100.0,
            delivery_days_actual=5.0,
            is_late_delivery=False,
            is_invalid_payment=False,
        )
        
        print(f"[OK] Request created: {request}")
        
        response = await predict_sentiment_endpoint(request)
        
        print(f"[OK] Response received")
        print(f"Sentiment: {response.sentiment}")
        print(f"Confidence: {response.confidence}")
        print(f"Delivery Context: {response.delivery_context}")
        print(f"Category: {response.category}")
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_api())
