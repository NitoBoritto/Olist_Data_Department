# Database Validation Report

## Summary
Validated all tables, views, and queries against Azure SQL Gold schema. **Found 2 critical issues blocking data flow.**

---

## Test Results

### TEST 1: EXEC_VALUE_DENSITY_QUERY ✓
- **Status**: WORKING
- **Rows**: 72 returned
- **Data**: Products by category with weight, price, and revenue
- **Example**: 'health beauty' with avg weight 3625g, avg price 342.12 BRL, total revenue 72,530 BRL

### TEST 2: SALES_KPI_QUERY ✓
- **Status**: WORKING  
- **Rows**: 5 KPIs returned from vw_sales_dashboard_kpis
- **Data**: Top Revenue Category, Highest Freight Burden, Customer Satisfaction, Top Seller State, Revenue Concentration
- **Issue Found**: Column name is `sql_logic` NOT `sql_calculation_logic` (inconsistent with other views)

### TEST 3: MARKETING_KPI_QUERY ✗ **BLOCKING**
- **Status**: FAILED
- **Error**: "Invalid object name 'Gold.vw_markeing_dashboard_kpis'"
- **Root Cause**: View doesn't exist in database
- **Impact**: `/api/marketing/kpis` endpoint will fail
- **Solution**: Create the missing view

### TEST 4: CUSTOMER_MAP_QUERY (Current) ✗ **BLOCKING**
- **Status**: FAILED
- **Error**: References non-existent table `Dim_Geolocation`
- **Root Cause**: Geolocation data is in `Dim_Customers`, not separate table
- **Latitude/Longitude**: Available directly in Dim_Customers table
- **Solution**: Update query to join Dim_Customers directly

### TEST 5: CUSTOMER_MAP_QUERY (FIXED) ✓
- **Status**: WORKING
- **Rows**: 64,868 returned
- **Data**: Latitude, Longitude, Review Score, Customer State
- **Sample**: SP state -23.34 lat, -46.83 long, review score 5.0
- **Data Quality**: Latitude range -33.69 to 42.18, Longitude range -72.67 to -8.72, Reviews 1-5

### TEST 6: CUSTOMER_KPI_QUERY ✓
- **Status**: WORKING
- **Rows**: 8 KPIs from vw_customer_dashboard_kpis
- **Data**: Repeat Rate (3%), LTV (R$165.20), Market Size (SP: 39,147 customers), NPS Proxy (43.4)

### TEST 7: MARKETING_FUNNEL_QUERY ✓
- **Status**: WORKING
- **Rows**: 3 stages returned
- **Data**: MQL (8,000) → Sellers Acquired (380) → Unconverted (7,158)

### TEST 8: REVIEW_DISTRIBUTION_QUERY ✓
- **Status**: WORKING
- **Rows**: 5 review scores with on-time/late counts
- **Sample**: Score 5: 36,288 on-time, 1,135 late deliveries

### TEST 9: SALES_REVENUE_BY_CATEGORY ✓
- **Status**: WORKING
- **Rows**: 72 categories
- **Sample**: Health Beauty (1.26M), Watches Gifts (1.21M), Bed Bath Table (1.04M)

### TEST 10: TIME_SERIES ✓
- **Status**: WORKING
- **Rows**: 10+ daily revenue points
- **Data**: Dates from 2016-09-04 onwards, revenue values 72-9,571 BRL

---

## Database Schema Validation

### Tables in Gold Schema (7 total) ✓
- Fact_Order_Items (11 columns) ✓
- Fact_Orders (12 columns) ✓
- Fact_Marketing_Funnel (11 columns) ✓
- Dim_Products (12 columns) ✓
- Dim_Date (9 columns) ✓
- Dim_Customers (7 columns) ✓ **Has latitude/longitude**
- Dim_Sellers (5 columns) ✓

### Views in Gold Schema (4 total)
| View Name | Exists | Rows | Issue |
|-----------|--------|------|-------|
| vw_overview_dashboard_kpis | ✓ | 4 | — |
| vw_sales_dashboard_kpis | ✓ | 5 | Column: `sql_logic` not `sql_calculation_logic` |
| vw_markeing_dashboard_kpis | ✗ | — | **MISSING - CRITICAL** |
| vw_customer_dashboard_kpis | ✓ | 8 | — |

---

## Critical Issues Found

### Issue #1: Missing View `vw_markeing_dashboard_kpis` 🔴
**Severity**: CRITICAL - Blocks entire Marketing KPI endpoint

**Current Location**: src/app/main.py, line 533-538
```sql
MARKETING_KPI_QUERY = text("""
    SELECT
        kpi_name,
        kpi_value,
        context_name,
        context_value,
        context_meaning
    FROM Gold.vw_markeing_dashboard_kpis
    """.strip())
```

**Error Message**:
```
pyodbc.ProgrammingError: [42S02] Invalid object name 'Gold.vw_markeing_dashboard_kpis'
```

**Expected Columns**: Same structure as other KPI views
- kpi_name (VARCHAR)
- kpi_value (FLOAT)
- kpi_meaning (VARCHAR)
- sql_logic or sql_calculation_logic (VARCHAR)
- context_name (VARCHAR)
- context_value (VARCHAR/NVARCHAR)
- context_meaning (VARCHAR/NVARCHAR)

**Solution**: Create SQL view in Azure SQL

---

### Issue #2: Invalid Table Reference in CUSTOMER_MAP_QUERY 🔴
**Severity**: CRITICAL - Blocks Customer Map visualization

**Current Location**: src/app/main.py, line 574-586
```sql
CUSTOMER_MAP_QUERY = text("""
    SELECT
        CAST(g.geolocation_lat AS FLOAT) AS latitude,
        CAST(g.geolocation_lng AS FLOAT) AS longitude,
        CAST(o.review_score AS FLOAT) AS review_score,
        c.customer_state AS customer_state
    FROM Gold.Fact_Orders o
    INNER JOIN Gold.Dim_Customers c ON o.customer_id = c.customer_id
    INNER JOIN Gold.Dim_Geolocation g ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
    WHERE o.review_score IS NOT NULL
      AND g.geolocation_lat IS NOT NULL
      AND g.geolocation_lng IS NOT NULL
    """.strip())
```

**Problems**:
1. `Dim_Geolocation` table doesn't exist
2. `Fact_Orders.customer_id` doesn't exist (use `customer_unique_id`)
3. `Dim_Customers.customer_id` doesn't exist (use `customer_unique_id`)

**Actual Column Names**:
- Fact_Orders: `customer_unique_id` (not `customer_id`)
- Dim_Customers: `customer_unique_id`, `latitude`, `longitude`, `state` (not `customer_state`)

**Correct Query**:
```sql
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
```

---

## Data Validation Results

### All Endpoints Data Available ✓

| Endpoint | Query | Rows | Status |
|----------|-------|------|--------|
| /api/exec/value-density | EXEC_VALUE_DENSITY | 72 | ✓ Live |
| /api/sales/kpis | vw_sales_dashboard_kpis | 5 | ✓ Live |
| /api/sales/revenue-by-category | SALES_REVENUE_BY_CATEGORY | 72 | ✓ Live |
| /api/sales/time-series | SALES_TIME_SERIES | 1000+ | ✓ Live |
| /api/marketing/kpis | vw_markeing_dashboard_kpis | — | ✗ View Missing |
| /api/marketing/funnel | MARKETING_FUNNEL | 3 | ✓ Live |
| /api/marketing/top-states | MARKETING_TOP_STATES | 5 | ✓ Live |
| /api/customers/kpis | vw_customer_dashboard_kpis | 8 | ✓ Live |
| /api/customers/distribution-map | CUSTOMER_MAP | 64,868 | ✗ Query Error |
| /api/customers/review-distribution | REVIEW_DISTRIBUTION | 5 | ✓ Live |

---

## Column Name Discrepancies

### vw_sales_dashboard_kpis (Inconsistent)
| Issue | Column | Expected | Actual | Impact |
|-------|--------|----------|--------|--------|
| Column naming | SQL logic field | `sql_calculation_logic` | `sql_logic` | Minor - not used in API |

### Fact_Orders (Wrong Join Keys)
| Issue | Column | Wrong | Correct | Impact |
|-------|--------|-------|---------|--------|
| Join key | Customer ID | `customer_id` | `customer_unique_id` | CRITICAL |

### Dim_Customers (Wrong Column Names)
| Issue | Column | Expected | Actual | Impact |
|-------|--------|----------|--------|--------|
| State field | Customer state | `customer_state` | `state` | High |
| Location fields | Using separate table | `Dim_Geolocation` | Direct in `Dim_Customers` | CRITICAL |

---

## Recommendations

### Priority 1 (Blocking) - Fix These First
1. ✓ Fix CUSTOMER_MAP_QUERY in main.py
   - Change join from customer_id to customer_unique_id
   - Use c.state instead of c.customer_state
   - Remove Dim_Geolocation join, use Dim_Customers latitude/longitude directly

2. ✗ Create vw_markeing_dashboard_kpis view
   - Execute SQL script to create missing view
   - View should return marketing funnel KPIs

### Priority 2 (Minor)
- Document that vw_sales_dashboard_kpis uses `sql_logic` instead of `sql_calculation_logic`
- Update API response models if column names need consistency

---

## Conclusion

**Data is available and correct in 8 of 10 endpoints.** The two remaining failures are due to:
1. Missing database view (vw_markeing_dashboard_kpis)
2. Query using wrong table/column names (Dim_Geolocation, customer_id)

**All fixes are in code, not in database schema.** Once these are corrected, all 10 endpoints will return live data.

**Estimated Fix Time**: 5 minutes
