"""Quick test of the inference pipeline."""
from src.serving.inference import predict_sentiment

# Test basic prediction
try:
    result = predict_sentiment(
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
    print("[OK] Prediction successful")
    print(f"Sentiment: {result['sentiment']}")
    print(f"Confidence: {result['confidence']:.4f}")
    print(f"Delivery Context: {result['delivery_context']}")
    print(f"Category: {result['category']}")
except Exception as e:
    print(f"[ERROR] {e}")
    import traceback
    traceback.print_exc()
