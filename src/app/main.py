"""
FastAPI application for Olist ML model serving.

Provides REST endpoints for sentiment analysis and dashboard KPIs.
"""

from datetime import datetime
from pathlib import Path
import sys
from typing import Any, Optional

import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from sqlalchemy import text

# Add project root to path
project_root = Path(__file__).parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from src.app.schema import SentimentRequest, SentimentResponse
from src.serving.inference import _load_models, predict_sentiment
from src.warehouse.engine import get_db_engine

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


class DashboardKpiCard(BaseModel):
    label: str
    value: Optional[float] = None
    display_value: str
    trend_label: Optional[str] = None
    trend_value: Optional[str] = None
    trend_tone: str = "neutral"
    meaning: Optional[str] = None
    sql_calculation_logic: Optional[str] = None
    context_name: Optional[str] = None
    context_value: Optional[str] = None
    context_meaning: Optional[str] = None


class OverviewDashboardResponse(BaseModel):
    source: str
    generated_at: str
    cards: dict[str, DashboardKpiCard]


class RevenueTrendPoint(BaseModel):
    date: str
    orders: int
    revenue: float


class RevenueTrendResponse(BaseModel):
    data: list[RevenueTrendPoint]
    generated_at: str


class CategoryProfitability(BaseModel):
    category: str
    total_sales: float
    units_sold: int
    freight_ratio_pct: float


class CategoryProfitabilityResponse(BaseModel):
    data: list[CategoryProfitability]
    generated_at: str


OVERVIEW_KPI_QUERY = text(
    """
    SELECT
        kpi_name,
        kpi_value,
        kpi_meaning,
        sql_calculation_logic,
        context_name,
        context_value,
        context_meaning
    FROM Gold.vw_overview_dashboard_kpis
    """.strip()
)

REVIEW_SCORE_FALLBACK_QUERY = text(
    """
    WITH valid_orders AS (
        SELECT
            d.year_number,
            o.review_score
        FROM Gold.Fact_Orders o
        INNER JOIN Gold.Dim_Date d
            ON o.purchase_date_key = d.date_key
        WHERE o.review_score IS NOT NULL
          AND o.order_status NOT IN ('created', 'approved')
    ),
    latest_year AS (
        SELECT MAX(year_number) AS max_year
        FROM valid_orders
    )
    SELECT
        AVG(CAST(v.review_score AS FLOAT)) AS avg_review_score,
        COUNT(*) AS review_count
    FROM valid_orders v
    INNER JOIN latest_year ly
        ON v.year_number = ly.max_year
    """.strip()
)


REVENUE_TREND_QUERY = text(
    """
    SELECT
        d.full_date,
        COUNT(o.order_id) AS total_orders,
        SUM(o.total_payment) AS daily_revenue
    FROM Gold.Fact_Orders o
    INNER JOIN Gold.Dim_Date d 
        ON o.purchase_date_key = d.date_key
    WHERE d.year_number = 2018
      AND o.order_status NOT IN ('created', 'approved')
    GROUP BY d.full_date
    ORDER BY d.full_date ASC
    """.strip()
)


CATEGORY_PROFITABILITY_QUERY = text(
    """
    SELECT
        p.category_name_en AS category,
        SUM(oi.price) AS total_sales,
        COUNT(DISTINCT oi.order_id) AS units_sold,
        ROUND((SUM(oi.freight_value) / NULLIF(SUM(oi.price), 0)) * 100, 2) AS freight_ratio_pct
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Products p 
        ON oi.product_id = p.product_id
    GROUP BY p.category_name_en
    HAVING SUM(oi.price) > 5000
    ORDER BY total_sales DESC
    """.strip()
)

OVERVIEW_KPI_ORDER = {
    "gross merchandise value (gmv)": "gmv",
    "avg review score": "review_score",
    "average review score": "review_score",
    "late delivery rate": "late_delivery_rate",
    "average order value (aov)": "aov",
}


def _safe_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _format_currency(value: Any) -> str:
    amount = _safe_float(value)
    if amount is None:
        return "—"
    return f"R$ {amount:,.2f}"


def _format_percent(value: Any) -> str:
    amount = _safe_float(value)
    if amount is None:
        return "—"
    return f"{amount:+.1f}%" if amount % 1 else f"{int(amount):+d}%"


def _format_percent_plain(value: Any) -> str:
    amount = _safe_float(value)
    if amount is None:
        return "—"
    return f"{amount:.1f}%" if amount % 1 else f"{int(amount)}%"


def _parse_percent(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        cleaned = value.strip().replace('%', '')
        try:
            return float(cleaned)
        except ValueError:
            return None
    return None


def _format_score(value: Any) -> str:
    amount = _safe_float(value)
    if amount is None:
        return "—"
    return f"{amount:.2f} / 5"


def _tone_from_text(text_value: Optional[str], default: str = "neutral") -> str:
    if not text_value:
        return default
    lowered = text_value.lower()
    if any(token in lowered for token in ("improved", "increased", "healthy", "strong", "good", "excellent", "stable")):
        return "positive"
    if any(token in lowered for token in ("declined", "decreased", "critical", "high", "negative", "risk")):
        return "negative"
    return default


def _normalize_overview_cards(rows: list[dict[str, Any]]) -> dict[str, DashboardKpiCard]:
    cards: dict[str, DashboardKpiCard] = {}

    for row in rows:
        kpi_name = (row.get("kpi_name") or "").strip().lower()
        kpi_key = OVERVIEW_KPI_ORDER.get(kpi_name)
        if not kpi_key:
            continue

        raw_value = row.get("kpi_value")
        if kpi_key in {"gmv", "aov"}:
            display_value = _format_currency(raw_value)
        elif kpi_key == "review_score":
            display_value = _format_score(raw_value)
        else:
            display_value = _format_percent_plain(raw_value)

        trend_text = row.get("context_value") or row.get("context_meaning") or ""
        cards[kpi_key] = DashboardKpiCard(
            label={
                "gmv": "Total GMV",
                "review_score": "Avg Review Score",
                "late_delivery_rate": "Late Delivery Rate",
                "aov": "AOV",
            }[kpi_key],
            value=_safe_float(raw_value),
            display_value=display_value,
            trend_label=row.get("context_name"),
            trend_value=trend_text or None,
            trend_tone=_tone_from_text(row.get("context_meaning"), default="neutral"),
            meaning=row.get("kpi_meaning"),
            sql_calculation_logic=row.get("sql_calculation_logic"),
            context_name=row.get("context_name"),
            context_value=row.get("context_value"),
            context_meaning=row.get("context_meaning"),
        )

        if kpi_key == "gmv":
            yoy_value = _parse_percent(row.get("context_value"))
            cards["yoy"] = DashboardKpiCard(
                label="YoY Revenue Growth",
                value=yoy_value,
                display_value=_format_percent(yoy_value),
                trend_label=row.get("context_name"),
                trend_value=row.get("context_meaning") or None,
                trend_tone=_tone_from_text(row.get("context_meaning"), default="neutral"),
                meaning="Year-over-year GMV change",
                sql_calculation_logic=row.get("sql_calculation_logic"),
                context_name=row.get("context_name"),
                context_value=row.get("context_value"),
                context_meaning=row.get("context_meaning"),
            )

    return cards


def _build_review_score_fallback(engine: Any) -> Optional[DashboardKpiCard]:
    frame = pd.read_sql(REVIEW_SCORE_FALLBACK_QUERY, engine)
    if frame.empty:
        return None

    row = frame.where(pd.notnull(frame), None).to_dict(orient="records")[0]
    score = _safe_float(row.get("avg_review_score"))
    if score is None:
        return None

    review_count = row.get("review_count")
    count_text = f"from {int(review_count)} reviews" if review_count is not None else None

    return DashboardKpiCard(
        label="Avg Review Score",
        value=score,
        display_value=_format_score(score),
        trend_label="Fallback Source",
        trend_value=count_text,
        trend_tone="neutral",
        meaning="Average customer review score (computed fallback)",
        sql_calculation_logic="AVG(CAST(review_score AS FLOAT)) from Gold.Fact_Orders (latest year)",
    )


def _load_overview_dashboard() -> OverviewDashboardResponse:
    try:
        engine = get_db_engine()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Dashboard database is unavailable: {exc}") from exc

    try:
        frame = pd.read_sql(OVERVIEW_KPI_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read overview dashboard data: {exc}") from exc

    if frame.empty:
        raise HTTPException(status_code=404, detail="No overview KPI rows were returned from the dashboard view.")

    records = frame.where(pd.notnull(frame), None).to_dict(orient="records")
    cards = _normalize_overview_cards(records)

    if "review_score" not in cards:
        try:
            fallback_review = _build_review_score_fallback(engine)
            if fallback_review is not None:
                cards["review_score"] = fallback_review
        except Exception:
            # Keep overview usable even if fallback query fails.
            pass

    if not cards:
        raise HTTPException(status_code=404, detail="Overview dashboard view did not return any of the expected KPI rows.")

    return OverviewDashboardResponse(
        source="Gold.vw_overview_dashboard_kpis",
        generated_at=datetime.utcnow().isoformat(),
        cards=cards,
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


@app.get("/api/dashboard/overview", response_model=OverviewDashboardResponse)
async def dashboard_overview():
    """Return the overview KPI cards from Gold.vw_overview_dashboard_kpis."""
    return _load_overview_dashboard()


@app.get("/api/dashboard/revenue-trend", response_model=RevenueTrendResponse)
async def dashboard_revenue_trend():
    """Return daily revenue and order volume trend data."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Dashboard database is unavailable: {exc}") from exc

    try:
        frame = pd.read_sql(REVENUE_TREND_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read revenue trend data: {exc}") from exc

    if frame.empty:
        return RevenueTrendResponse(data=[], generated_at=datetime.utcnow().isoformat())

    data = []
    for _, row in frame.iterrows():
        date_str = str(row["full_date"]).split()[0] if row["full_date"] else ""
        data.append(
            RevenueTrendPoint(
                date=date_str,
                orders=int(row["total_orders"]) if row["total_orders"] else 0,
                revenue=float(row["daily_revenue"]) if row["daily_revenue"] else 0.0,
            )
        )

    return RevenueTrendResponse(data=data, generated_at=datetime.utcnow().isoformat())


@app.get("/api/dashboard/category-profitability", response_model=CategoryProfitabilityResponse)
async def dashboard_category_profitability():
    """Return category profitability and freight ratio analysis."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Dashboard database is unavailable: {exc}") from exc

    try:
        frame = pd.read_sql(CATEGORY_PROFITABILITY_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read category profitability data: {exc}") from exc

    if frame.empty:
        return CategoryProfitabilityResponse(data=[], generated_at=datetime.utcnow().isoformat())

    data = [
        CategoryProfitability(
            category=str(row["category"]) if row["category"] else "Unknown",
            total_sales=float(row["total_sales"]) if row["total_sales"] else 0.0,
            units_sold=int(row["units_sold"]) if row["units_sold"] else 0,
            freight_ratio_pct=float(row["freight_ratio_pct"]) if row["freight_ratio_pct"] else 0.0,
        )
        for _, row in frame.iterrows()
    ]

    return CategoryProfitabilityResponse(data=data, generated_at=datetime.utcnow().isoformat())



@app.post("/api/predict/sentiment", response_model=SentimentResponse)
async def predict_sentiment_endpoint(request: SentimentRequest) -> SentimentResponse:
    """
    Predict sentiment for a review.
    
    Returns sentiment label, confidence score, and delivery context.
    """
    try:
        result = await predict_sentiment(text=request.text)
        
        return SentimentResponse(
            sentiment=result["sentiment"],
            confidence=result["confidence"],
            delivery_context="Sentiment analysis from review text",
            category="General",
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
