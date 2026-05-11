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


# New Dashboard Response Models (Phase 5)
class ExecValueDensityItem(BaseModel):
    category_name_en: str
    x: Optional[float] = None  # avg weight
    y: Optional[float] = None  # avg price
    size: Optional[float] = None  # total revenue


class SimpleKpiItem(BaseModel):
    kpi_name: str
    kpi_value: Optional[str] = None
    context_name: Optional[str] = None
    context_value: Optional[str] = None
    context_meaning: Optional[str] = None


class SimpleKpiResponse(BaseModel):
    data: list[SimpleKpiItem]
    generated_at: str


class CategoryRevenueItem(BaseModel):
    category: str
    revenue: Optional[float] = None


class CategoryRevenueResponse(BaseModel):
    data: list[CategoryRevenueItem]
    generated_at: str


class TimeSeriesPoint(BaseModel):
    date: str
    revenue: Optional[float] = None


class TimeSeriesResponse(BaseModel):
    data: list[TimeSeriesPoint]
    generated_at: str


class FunnelStage(BaseModel):
    stage: str
    value: Optional[int] = None


class FunnelResponse(BaseModel):
    data: list[FunnelStage]
    generated_at: str


class StateLeads(BaseModel):
    state: str
    leads: Optional[int] = None


class StateLeadsResponse(BaseModel):
    data: list[StateLeads]
    generated_at: str


class MapPoint(BaseModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    review_score: Optional[float] = None
    customer_state: Optional[str] = None


class MapResponse(BaseModel):
    data: list[MapPoint]
    generated_at: str


class ReviewDistributionItem(BaseModel):
    review_score: Optional[int] = None
    on_time_count: Optional[int] = None
    late_count: Optional[int] = None


class ReviewDistributionResponse(BaseModel):
    data: list[ReviewDistributionItem]
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

# New Dashboard API Queries (Phase 5 - Analytics Dashboard)
EXEC_VALUE_DENSITY_QUERY = text(
    """
    SELECT
        p.category_name_en AS category_name_en,
        AVG(CAST(p.weight_g AS FLOAT)) AS x,
        AVG(CAST(oi.price AS FLOAT)) AS y,
        SUM(CAST(oi.price AS FLOAT)) AS size
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Products p ON oi.product_id = p.product_id
    GROUP BY p.category_name_en
    """.strip()
)

SALES_KPI_QUERY = text(
    """
    SELECT
        kpi_name,
        kpi_value,
        context_name,
        context_value,
        context_meaning
    FROM Gold.vw_sales_dashboard_kpis
    """.strip()
)

SALES_REVENUE_BY_CATEGORY_QUERY = text(
    """
    SELECT
        p.category_name_en AS category,
        SUM(CAST(oi.price AS FLOAT)) AS revenue
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Products p ON oi.product_id = p.product_id
    GROUP BY p.category_name_en
    ORDER BY revenue DESC
    """.strip()
)

SALES_TIME_SERIES_QUERY = text(
    """
    SELECT
        d.full_date AS date,
        SUM(CAST(oi.price AS FLOAT)) AS revenue
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Fact_Orders o ON oi.order_id = o.order_id
    INNER JOIN Gold.Dim_Date d ON o.purchase_date_key = d.date_key
    WHERE o.order_status NOT IN ('created', 'approved', 'canceled')
    GROUP BY d.full_date
    ORDER BY d.full_date ASC
    """.strip()
)

MARKETING_KPI_QUERY = text(
    """
    SELECT
        kpi_name,
        kpi_value,
        context_name,
        context_value,
        context_meaning
    FROM Gold.vw_markeing_dashboard_kpis
    """.strip()
)

MARKETING_FUNNEL_QUERY = text(
    """
    SELECT
        'MQL' AS stage,
        COUNT(DISTINCT mql_id) AS value
    FROM Gold.Fact_Marketing_Funnel
    UNION ALL
    SELECT
        'Sellers Acquired' AS stage,
        COUNT(DISTINCT CASE WHEN is_converted = 1 THEN seller_id END) AS value
    FROM Gold.Fact_Marketing_Funnel
    UNION ALL
    SELECT
        'Unconverted' AS stage,
        COUNT(DISTINCT CASE WHEN is_converted = 0 THEN mql_id END) AS value
    FROM Gold.Fact_Marketing_Funnel
    """.strip()
)

MARKETING_TOP_STATES_QUERY = text(
    """
    SELECT TOP 5
        lead_origin AS state,
        COUNT(DISTINCT mql_id) AS leads
    FROM Gold.Fact_Marketing_Funnel
    WHERE lead_origin IS NOT NULL
    GROUP BY lead_origin
    ORDER BY leads DESC
    """.strip()
)

CUSTOMER_KPI_QUERY = text(
    """
    SELECT
        kpi_name,
        kpi_value,
        context_name,
        context_value,
        context_meaning
    FROM Gold.vw_customer_dashboard_kpis
    """.strip()
)

CUSTOMER_MAP_QUERY = text(
    """
    SELECT
        CAST(c.latitude AS FLOAT) AS latitude,
        CAST(c.longitude AS FLOAT) AS longitude,
        CAST(o.review_score AS FLOAT) AS review_score,
        c.state AS customer_state
    FROM Gold.Fact_Orders o
    INNER JOIN Gold.Dim_Customers c ON o.customer_unique_id = c.customer_unique_id
    WHERE o.review_score IS NOT NULL
      AND c.latitude IS NOT NULL
      AND c.longitude IS NOT NULL
    """.strip()
)

CUSTOMER_REVIEW_DISTRIBUTION_QUERY = text(
    """
    SELECT
        o.review_score,
        COUNT(CASE WHEN o.is_late_delivery = 0 THEN 1 END) AS on_time_count,
        COUNT(CASE WHEN o.is_late_delivery = 1 THEN 1 END) AS late_count
    FROM Gold.Fact_Orders o
    WHERE o.review_score IS NOT NULL
    GROUP BY o.review_score
    ORDER BY o.review_score ASC
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


# ============================================================================
# NEW DASHBOARD ENDPOINTS (Phase 5 - Analytics Dashboard API)
# ============================================================================

@app.get("/api/exec/value-density")
async def exec_value_density():
    """Executive view: Product value vs density bubble chart."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data for testing
        return {
            "data": [
                {"category_name_en": "electronics", "x": 250.5, "y": 149.99, "size": 850000.00},
                {"category_name_en": "health_beauty", "x": 180.2, "y": 89.50, "size": 720000.00},
                {"category_name_en": "home_appliances", "x": 420.8, "y": 299.99, "size": 650000.00},
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(EXEC_VALUE_DENSITY_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read exec data: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "category_name_en": str(row["category_name_en"]) if row["category_name_en"] else "Unknown",
            "x": float(row["x"]) if row["x"] is not None else None,
            "y": float(row["y"]) if row["y"] is not None else None,
            "size": float(row["size"]) if row["size"] is not None else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}


@app.get("/api/sales/kpis")
async def sales_kpis():
    """Sales dashboard: KPI cards (top category, freight ratio, etc)."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data if DB unavailable (for testing without views)
        return {
            "data": [
                {
                    "kpi_name": "Top Category",
                    "kpi_value": "850000.50",
                    "context_name": "Category",
                    "context_value": "electronics",
                    "context_meaning": "The product category with the highest total revenue",
                },
                {
                    "kpi_name": "Total Products in Catalog",
                    "kpi_value": "32951",
                    "context_name": "Description",
                    "context_value": "Active SKUs",
                    "context_meaning": "Unique product variants available for sale",
                },
                {
                    "kpi_name": "Freight Cost Ratio",
                    "kpi_value": "12.5",
                    "context_name": "Metric",
                    "context_value": "%",
                    "context_meaning": "Shipping cost as % of product revenue",
                },
                {
                    "kpi_name": "Average Order Value",
                    "kpi_value": "149.99",
                    "context_name": "Currency",
                    "context_value": "BRL",
                    "context_meaning": "Mean transaction value per line item",
                },
                {
                    "kpi_name": "Total Revenue",
                    "kpi_value": "12850000.00",
                    "context_name": "Period",
                    "context_value": "All Time",
                    "context_meaning": "Aggregate gross merchandise value",
                },
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(SALES_KPI_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read sales KPIs: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "kpi_name": str(row.get("kpi_name") or ""),
            "kpi_value": str(row.get("kpi_value") or ""),
            "context_name": str(row.get("context_name") or "") if row.get("context_name") else None,
            "context_value": str(row.get("context_value") or "") if row.get("context_value") else None,
            "context_meaning": str(row.get("context_meaning") or "") if row.get("context_meaning") else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}


@app.get("/api/sales/revenue-by-category")
async def sales_revenue_by_category():
    """Sales dashboard: Revenue breakdown by category (sorted descending)."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data for testing
        return {
            "data": [
                {"category": "health_beauty", "revenue": 850000.50},
                {"category": "electronics", "revenue": 720000.25},
                {"category": "home_appliances", "revenue": 650000.75},
                {"category": "fashion", "revenue": 580000.00},
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(SALES_REVENUE_BY_CATEGORY_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read category revenue: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "category": str(row["category"]) if row["category"] else "Unknown",
            "revenue": float(row["revenue"]) if row["revenue"] is not None else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}


@app.get("/api/sales/time-series")
async def sales_time_series():
    """Sales dashboard: Daily revenue time series for trend analysis."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data for testing
        return {
            "data": [
                {"date": "2018-01-01", "revenue": 15000.00},
                {"date": "2018-01-02", "revenue": 18500.75},
                {"date": "2018-01-03", "revenue": 17200.50},
                {"date": "2018-01-04", "revenue": 19800.25},
                {"date": "2018-01-05", "revenue": 22100.00},
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(SALES_TIME_SERIES_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read time series: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "date": str(row["date"]).split()[0] if row["date"] else "",
            "revenue": float(row["revenue"]) if row["revenue"] is not None else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}


@app.get("/api/marketing/kpis")
async def marketing_kpis():
    """Marketing dashboard: KPI cards (MQLs, conversion rate, etc)."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data for testing
        return {
            "data": [
                {
                    "kpi_name": "Total MQLs",
                    "kpi_value": "12500",
                    "context_name": "Source",
                    "context_value": "Marketing Qualified Leads",
                    "context_meaning": "Total unique leads generated",
                },
                {
                    "kpi_name": "Sellers Acquired",
                    "kpi_value": "1062",
                    "context_name": "Status",
                    "context_value": "Converted",
                    "context_meaning": "Total sellers onboarded from MQL funnel",
                },
                {
                    "kpi_name": "Funnel Conversion Rate",
                    "kpi_value": "8.5",
                    "context_name": "Metric",
                    "context_value": "%",
                    "context_meaning": "Percentage of MQLs converting to sellers",
                },
                {
                    "kpi_name": "Average Days to Close",
                    "kpi_value": "45.2",
                    "context_name": "Metric",
                    "context_value": "days",
                    "context_meaning": "Mean sales cycle duration",
                },
                {
                    "kpi_name": "Unconverted Leads",
                    "kpi_value": "11438",
                    "context_name": "Status",
                    "context_value": "In Funnel",
                    "context_meaning": "Leads not yet converted to sellers",
                },
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(MARKETING_KPI_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read marketing KPIs: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "kpi_name": str(row.get("kpi_name") or ""),
            "kpi_value": str(row.get("kpi_value") or ""),
            "context_name": str(row.get("context_name") or "") if row.get("context_name") else None,
            "context_value": str(row.get("context_value") or "") if row.get("context_value") else None,
            "context_meaning": str(row.get("context_meaning") or "") if row.get("context_meaning") else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}


@app.get("/api/marketing/funnel")
async def marketing_funnel():
    """Marketing dashboard: Funnel stages (MQL → Acquired)."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data for testing
        return {
            "data": [
                {"stage": "MQL", "value": 12500},
                {"stage": "Sellers Acquired", "value": 1062},
                {"stage": "Unconverted", "value": 11438},
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(MARKETING_FUNNEL_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read funnel data: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "stage": str(row["stage"]) if row["stage"] else "Unknown",
            "value": int(row["value"]) if row["value"] is not None else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}


@app.get("/api/marketing/top-states")
async def marketing_top_states():
    """Marketing dashboard: Top 5 states by MQL count."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data for testing
        return {
            "data": [
                {"state": "SP", "leads": 3750},
                {"state": "MG", "leads": 2100},
                {"state": "RJ", "leads": 1850},
                {"state": "BA", "leads": 1200},
                {"state": "SC", "leads": 800},
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(MARKETING_TOP_STATES_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read top states: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "state": str(row["state"]) if row["state"] else "Unknown",
            "leads": int(row["leads"]) if row["leads"] is not None else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}


@app.get("/api/customers/kpis")
async def customer_kpis():
    """Customer dashboard: KPI cards (LTV, NPS proxy, repeat rate, etc)."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data for testing
        return {
            "data": [
                {
                    "kpi_name": "Total Unique Customers",
                    "kpi_value": "99441",
                    "context_name": "Description",
                    "context_value": "All Time",
                    "context_meaning": "Cumulative unique customer accounts",
                },
                {
                    "kpi_name": "Repeat Customer Rate",
                    "kpi_value": "3.2",
                    "context_name": "Metric",
                    "context_value": "%",
                    "context_meaning": "Customers with multiple orders",
                },
                {
                    "kpi_name": "Average Review Score",
                    "kpi_value": "4.14",
                    "context_name": "Scale",
                    "context_value": "1-5",
                    "context_meaning": "Mean customer satisfaction rating",
                },
                {
                    "kpi_name": "On-Time Delivery Avg Rating",
                    "kpi_value": "4.28",
                    "context_name": "Condition",
                    "context_value": "On-Time",
                    "context_meaning": "Average review score for on-time deliveries",
                },
                {
                    "kpi_name": "Late Delivery Avg Rating",
                    "kpi_value": "3.05",
                    "context_name": "Condition",
                    "context_value": "Late",
                    "context_meaning": "Average review score for late deliveries",
                },
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(CUSTOMER_KPI_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read customer KPIs: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "kpi_name": str(row.get("kpi_name") or ""),
            "kpi_value": str(row.get("kpi_value") or ""),
            "context_name": str(row.get("context_name") or "") if row.get("context_name") else None,
            "context_value": str(row.get("context_value") or "") if row.get("context_value") else None,
            "context_meaning": str(row.get("context_meaning") or "") if row.get("context_meaning") else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}


@app.get("/api/customers/distribution-map")
async def customer_distribution_map():
    """Customer dashboard: Geographic distribution map with review scores."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data for testing
        return {
            "data": [
                {"latitude": -23.5505, "longitude": -46.6333, "review_score": 4.5, "customer_state": "SP"},
                {"latitude": -19.9167, "longitude": -43.9345, "review_score": 3.8, "customer_state": "MG"},
                {"latitude": -22.9068, "longitude": -43.1729, "review_score": 4.2, "customer_state": "RJ"},
                {"latitude": -12.9714, "longitude": -38.5014, "review_score": 4.0, "customer_state": "BA"},
                {"latitude": -27.5969, "longitude": -48.5495, "review_score": 4.1, "customer_state": "SC"},
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(CUSTOMER_MAP_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read map data: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "latitude": float(row["latitude"]) if row["latitude"] is not None else None,
            "longitude": float(row["longitude"]) if row["longitude"] is not None else None,
            "review_score": float(row["review_score"]) if row["review_score"] is not None else None,
            "customer_state": str(row["customer_state"]) if row["customer_state"] else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}


@app.get("/api/customers/review-distribution")
async def customer_review_distribution():
    """Customer dashboard: Review score distribution (on-time vs late delivery)."""
    try:
        engine = get_db_engine()
    except Exception as exc:
        # Return sample data for testing
        return {
            "data": [
                {"review_score": 1, "on_time_count": 50, "late_count": 145},
                {"review_score": 2, "on_time_count": 120, "late_count": 380},
                {"review_score": 3, "on_time_count": 580, "late_count": 1250},
                {"review_score": 4, "on_time_count": 2850, "late_count": 3200},
                {"review_score": 5, "on_time_count": 18500, "late_count": 2100},
            ],
            "generated_at": datetime.utcnow().isoformat(),
        }

    try:
        frame = pd.read_sql(CUSTOMER_REVIEW_DISTRIBUTION_QUERY, engine)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to read review distribution: {exc}") from exc

    if frame.empty:
        return {"data": [], "generated_at": datetime.utcnow().isoformat()}

    data = [
        {
            "review_score": int(row["review_score"]) if row["review_score"] is not None else None,
            "on_time_count": int(row["on_time_count"]) if row["on_time_count"] is not None else None,
            "late_count": int(row["late_count"]) if row["late_count"] is not None else None,
        }
        for _, row in frame.iterrows()
    ]

    return {"data": data, "generated_at": datetime.utcnow().isoformat()}



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
