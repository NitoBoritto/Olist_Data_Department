# Analytics Dashboard API - Endpoint Reference

## Overview
10 REST endpoints serving JSON data to Plotly.js visualizations. All endpoints return `200 OK` with data, or `502/503` on failure.

---

## ✓ Implemented Endpoints

### 1. Executive Dashboard
#### `GET /api/exec/value-density`
**Purpose:** Bubble chart (Product Value vs Density)

**Response:**
```json
{
  "data": [
    {
      "category_name_en": "electronics",
      "x": 250.5,
      "y": 149.99,
      "size": 850000.00
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Chart Type:** Scatter bubble (X=weight, Y=price, size=revenue)

---

### 2. Sales Dashboard - KPIs
#### `GET /api/sales/kpis`
**Purpose:** KPI cards (Top Category, Freight Ratio, Products, AOV, Total Revenue)

**Response:**
```json
{
  "data": [
    {
      "kpi_name": "Top Category",
      "kpi_value": "82000.50",
      "context_name": "Category",
      "context_value": "health_beauty",
      "context_meaning": "The product category with highest revenue"
    },
    {
      "kpi_name": "Freight Cost Ratio",
      "kpi_value": "12.5",
      "context_name": "Metric",
      "context_value": "%",
      "context_meaning": "Shipping cost as % of product revenue"
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Expected Parsing:** JavaScript uses `getKpiByAliases(data, ["top_category", "freight_ratio", "products_in_catalog", "average_order_value", "total_revenue"])`

---

### 3. Sales Dashboard - Category Revenue
#### `GET /api/sales/revenue-by-category`
**Purpose:** Horizontal bar chart (Top categories by revenue)

**Response:**
```json
{
  "data": [
    {
      "category": "health_beauty",
      "revenue": 850000.50
    },
    {
      "category": "electronics",
      "revenue": 720000.25
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Chart Type:** Horizontal bar (sorted descending)

---

### 4. Sales Dashboard - Time Series
#### `GET /api/sales/time-series`
**Purpose:** Line chart with trend (Daily revenue + 30D moving average)

**Response:**
```json
{
  "data": [
    {
      "date": "2018-01-01",
      "revenue": 15000.00
    },
    {
      "date": "2018-01-02",
      "revenue": 18500.75
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Chart Type:** Dual-line (Actual + 30D MA, calculated client-side)

**Note:** Dates must be sorted ascending for client-side moving average calculation.

---

### 5. Marketing Dashboard - KPIs
#### `GET /api/marketing/kpis`
**Purpose:** KPI cards (MQLs, Conversion Rate, Days to Close, Sellers Acquired, Unconverted)

**Response:**
```json
{
  "data": [
    {
      "kpi_name": "Total MQLs",
      "kpi_value": "12500",
      "context_name": "Source",
      "context_value": "Marketing Qualified Leads",
      "context_meaning": "Total unique leads generated"
    },
    {
      "kpi_name": "Funnel Conversion Rate",
      "kpi_value": "8.5",
      "context_name": "Metric",
      "context_value": "%",
      "context_meaning": "Percentage of MQLs converting to sellers"
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Expected Parsing:** JavaScript uses `getKpiByAliases(data, ["total_mqls", "conversion_rate", "avg_days_to_close", "sellers_acquired", "unconverted_leads"])`

---

### 6. Marketing Dashboard - Funnel
#### `GET /api/marketing/funnel`
**Purpose:** Funnel chart (MQL → Acquired)

**Response:**
```json
{
  "data": [
    {
      "stage": "MQL",
      "value": 12500
    },
    {
      "stage": "Sellers Acquired",
      "value": 1062
    },
    {
      "stage": "Unconverted",
      "value": 11438
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Chart Type:** Plotly funnel (stages in order, values as integers)

---

### 7. Marketing Dashboard - Top States
#### `GET /api/marketing/top-states`
**Purpose:** Pie/Donut chart (Top 5 states by MQL count)

**Response:**
```json
{
  "data": [
    {
      "state": "SP",
      "leads": 3750
    },
    {
      "state": "MG",
      "leads": 2100
    },
    {
      "state": "RJ",
      "leads": 1850
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Chart Type:** Pie/Donut (hole=0.4)

---

### 8. Customer Dashboard - KPIs
#### `GET /api/customers/kpis`
**Purpose:** KPI cards (LTV, Repeat Rate, NPS Proxy, On-Time Rating, Late Rating)

**Response:**
```json
{
  "data": [
    {
      "kpi_name": "Total Unique Customers",
      "kpi_value": "99441",
      "context_name": "Description",
      "context_value": "All Time",
      "context_meaning": "Cumulative unique customer accounts"
    },
    {
      "kpi_name": "Repeat Customer Rate",
      "kpi_value": "3.2",
      "context_name": "Metric",
      "context_value": "%",
      "context_meaning": "Customers with multiple orders"
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Expected Parsing:** JavaScript uses `getKpiByAliases(data, ["total_unique_customers", "repeat_customer_rate", "average_review_score", "on_time_delivery_avg_rating", "late_delivery_avg_rating"])`

---

### 9. Customer Dashboard - Geography Map
#### `GET /api/customers/distribution-map`
**Purpose:** Scattermapbox (Brazil customer locations with review scores)

**Response:**
```json
{
  "data": [
    {
      "latitude": -23.5505,
      "longitude": -46.6333,
      "review_score": 4.5,
      "customer_state": "SP"
    },
    {
      "latitude": -19.9167,
      "longitude": -43.9345,
      "review_score": 3.8,
      "customer_state": "MG"
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Chart Type:** Scattermapbox (color scale: red=low review, green=high review)

**Required Mapbox Token:** API requires free Mapbox token for rendering.

---

### 10. Customer Dashboard - Review Distribution
#### `GET /api/customers/review-distribution`
**Purpose:** Grouped bar chart (On-time vs Late by review score)

**Response:**
```json
{
  "data": [
    {
      "review_score": 1,
      "on_time_count": 50,
      "late_count": 145
    },
    {
      "review_score": 2,
      "on_time_count": 120,
      "late_count": 380
    },
    {
      "review_score": 5,
      "on_time_count": 18500,
      "late_count": 2100
    }
  ],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

**Chart Type:** Grouped bar (X=review_score, two traces: on_time_count, late_count)

---

## Error Responses

### 503 Service Unavailable
Database connection failed (AZURE_SQL_STRING not set, network issue, etc.)
```json
{
  "detail": "Database unavailable: [error message]"
}
```

### 502 Bad Gateway
Query execution failed
```json
{
  "detail": "Failed to read [endpoint name]: [error message]"
}
```

### 200 OK (Empty Response)
Query executed but returned no rows
```json
{
  "data": [],
  "generated_at": "2024-01-15T10:30:45.123456"
}
```

---

## Frontend Integration Status

### Charts.js File Mappings
All 10 endpoints are already integrated in `src/app/js/charts.js`:

| Endpoint | Handler Function | Chart Type |
|----------|-----------------|-----------|
| `/api/exec/value-density` | `renderProductValueDensity()` | Scatter Bubble |
| `/api/sales/kpis` | `loadSalesKpis()` | KPI Cards |
| `/api/sales/revenue-by-category` | `renderSalesRevenueByCategory()` | Horizontal Bar |
| `/api/sales/time-series` | `renderSalesTrendsForecast()` | Line + MA |
| `/api/marketing/kpis` | `loadMarketingKpis()` | KPI Cards |
| `/api/marketing/funnel` | `renderMarketingFunnel()` | Funnel |
| `/api/marketing/top-states` | `renderMarketingTopStates()` | Pie/Donut |
| `/api/customers/kpis` | `loadCustomerKpis()` | KPI Cards |
| `/api/customers/distribution-map` | `renderCustomerMap()` | Scattermapbox |
| `/api/customers/review-distribution` | `renderReviewDistribution()` | Grouped Bar |

---

## Deployment Checklist

- [ ] 1. Execute `scripts/create_dashboard_views.sql` on Azure SQL database
- [ ] 2. Verify all 3 views created: `vw_sales_dashboard_kpis`, `vw_markeing_dashboard_kpis`, `vw_customer_dashboard_kpis`
- [ ] 3. Restart FastAPI: `python -m uvicorn src.app.main:app --reload`
- [ ] 4. Test `/api/health` endpoint returns `{"status": "ok", "models": ["sentiment"]}`
- [ ] 5. Test `/api/sales/kpis` returns JSON with data array
- [ ] 6. Open dashboard in browser, verify all charts populate with data
- [ ] 7. Check browser DevTools Network tab for no 404 errors
- [ ] 8. Verify all KPI values display as numbers (not "--")

---

## Quick Test Command
```bash
curl -X GET http://localhost:8000/api/sales/kpis | python -m json.tool
```

---

## Notes
- All timestamps in UTC ISO 8601 format
- Numeric values may be NULL or omitted; frontend must handle with fallback
- Date strings are ISO format (YYYY-MM-DD)
- State codes use BR abbreviations (SP, MG, RJ, BA, etc.)
- Coordinates in WGS84 decimal degrees
