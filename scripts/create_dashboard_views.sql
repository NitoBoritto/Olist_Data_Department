-- ============================================================================
-- Dashboard Views Creation Script
-- ============================================================================
-- This script creates all required views for the Analytics Dashboard API
-- Execute this script against your Azure SQL database before running the API
-- ============================================================================

USE [olist];
GO

-- ============================================================================
-- View 1: Sales Dashboard KPIs
-- ============================================================================
IF OBJECT_ID('Gold.vw_sales_dashboard_kpis', 'V') IS NOT NULL
  DROP VIEW Gold.vw_sales_dashboard_kpis;
GO

CREATE VIEW Gold.vw_sales_dashboard_kpis AS
SELECT
    'Top Category' AS kpi_name,
    CAST(MAX(revenue) AS VARCHAR(50)) AS kpi_value,
    'Category' AS context_name,
    category_name_en AS context_value,
    'The product category with the highest total revenue' AS context_meaning
FROM (
    SELECT TOP 1
        p.category_name_en,
        SUM(CAST(oi.price * oi.order_item_quantity AS FLOAT)) AS revenue
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Products p ON oi.product_id = p.product_id
    GROUP BY p.category_name_en
    ORDER BY revenue DESC
) t
GROUP BY category_name_en

UNION ALL

SELECT
    'Total Products in Catalog' AS kpi_name,
    CAST(COUNT(DISTINCT product_id) AS VARCHAR(50)) AS kpi_value,
    'Description' AS context_name,
    'Active SKUs' AS context_value,
    'Unique product variants available for sale' AS context_meaning
FROM Gold.Fact_Order_Items

UNION ALL

SELECT
    'Freight Cost Ratio' AS kpi_name,
    CAST(ROUND((SUM(CAST(freight_value AS FLOAT)) / NULLIF(SUM(CAST(price * order_item_quantity AS FLOAT)), 0)) * 100, 2) AS VARCHAR(50)) AS kpi_value,
    'Metric' AS context_name,
    '%' AS context_value,
    'Shipping cost as % of product revenue' AS context_meaning
FROM Gold.Fact_Order_Items

UNION ALL

SELECT
    'Average Order Value' AS kpi_name,
    CAST(ROUND(AVG(CAST(price * order_item_quantity AS FLOAT)), 2) AS VARCHAR(50)) AS kpi_value,
    'Currency' AS context_name,
    'BRL' AS context_value,
    'Mean transaction value per line item' AS context_meaning
FROM Gold.Fact_Order_Items

UNION ALL

SELECT
    'Total Revenue' AS kpi_name,
    CAST(ROUND(SUM(CAST(price * order_item_quantity AS FLOAT)), 2) AS VARCHAR(50)) AS kpi_value,
    'Period' AS context_name,
    'All Time' AS context_value,
    'Aggregate gross merchandise value' AS context_meaning
FROM Gold.Fact_Order_Items;

GO

-- ============================================================================
-- View 2: Marketing Dashboard KPIs
-- ============================================================================
IF OBJECT_ID('Gold.vw_markeing_dashboard_kpis', 'V') IS NOT NULL
  DROP VIEW Gold.vw_markeing_dashboard_kpis;
GO

CREATE VIEW Gold.vw_markeing_dashboard_kpis AS
SELECT
    'Total MQLs' AS kpi_name,
    CAST(COUNT(DISTINCT mql_id) AS VARCHAR(50)) AS kpi_value,
    'Source' AS context_name,
    'Marketing Qualified Leads' AS context_value,
    'Total unique leads generated' AS context_meaning
FROM Gold.Fact_Marketing_Funnel

UNION ALL

SELECT
    'Sellers Acquired' AS kpi_name,
    CAST(COUNT(DISTINCT seller_id) AS VARCHAR(50)) AS kpi_value,
    'Status' AS context_name,
    'Converted' AS context_value,
    'Total sellers onboarded from MQL funnel' AS context_meaning
FROM Gold.Fact_Marketing_Funnel
WHERE is_converted = 1

UNION ALL

SELECT
    'Funnel Conversion Rate' AS kpi_name,
    CAST(ROUND((CAST(COUNT(DISTINCT CASE WHEN is_converted = 1 THEN seller_id END) AS FLOAT) / NULLIF(COUNT(DISTINCT mql_id), 0)) * 100, 2) AS VARCHAR(50)) AS kpi_value,
    'Metric' AS context_name,
    '%' AS context_value,
    'Percentage of MQLs converting to sellers' AS context_meaning
FROM Gold.Fact_Marketing_Funnel

UNION ALL

SELECT
    'Average Days to Close' AS kpi_name,
    CAST(ROUND(AVG(CAST(DATEDIFF(DAY, first_contact_date, won_date) AS FLOAT)), 1) AS VARCHAR(50)) AS kpi_value,
    'Metric' AS context_name,
    'days' AS context_value,
    'Mean sales cycle duration' AS context_meaning
FROM Gold.Fact_Marketing_Funnel
WHERE won_date IS NOT NULL

UNION ALL

SELECT
    'Unconverted Leads' AS kpi_name,
    CAST(COUNT(DISTINCT CASE WHEN is_converted = 0 THEN mql_id END) AS VARCHAR(50)) AS kpi_value,
    'Status' AS context_name,
    'In Funnel' AS context_value,
    'Leads not yet converted to sellers' AS context_meaning
FROM Gold.Fact_Marketing_Funnel;

GO

-- ============================================================================
-- View 3: Customer Dashboard KPIs
-- ============================================================================
IF OBJECT_ID('Gold.vw_customer_dashboard_kpis', 'V') IS NOT NULL
  DROP VIEW Gold.vw_customer_dashboard_kpis;
GO

CREATE VIEW Gold.vw_customer_dashboard_kpis AS
SELECT
    'Total Unique Customers' AS kpi_name,
    CAST(COUNT(DISTINCT customer_id) AS VARCHAR(50)) AS kpi_value,
    'Description' AS context_name,
    'All Time' AS context_value,
    'Cumulative unique customer accounts' AS context_meaning
FROM Gold.Fact_Orders

UNION ALL

SELECT
    'Repeat Customer Rate' AS kpi_name,
    CAST(ROUND((CAST(COUNT(DISTINCT CASE WHEN order_count > 1 THEN customer_id END) AS FLOAT) / NULLIF(COUNT(DISTINCT customer_id), 0)) * 100, 2) AS VARCHAR(50)) AS kpi_value,
    'Metric' AS context_name,
    '%' AS context_value,
    'Customers with multiple orders' AS context_meaning
FROM (
    SELECT customer_id, COUNT(*) AS order_count
    FROM Gold.Fact_Orders
    GROUP BY customer_id
) t

UNION ALL

SELECT
    'Average Review Score' AS kpi_name,
    CAST(ROUND(AVG(CAST(review_score AS FLOAT)), 2) AS VARCHAR(50)) AS kpi_value,
    'Scale' AS context_name,
    '1-5' AS context_value,
    'Mean customer satisfaction rating' AS context_meaning
FROM Gold.Fact_Orders
WHERE review_score IS NOT NULL

UNION ALL

SELECT
    'On-Time Delivery Avg Rating' AS kpi_name,
    CAST(ROUND(AVG(CAST(review_score AS FLOAT)), 2) AS VARCHAR(50)) AS kpi_value,
    'Condition' AS context_name,
    'On-Time' AS context_value,
    'Average review score for on-time deliveries' AS context_meaning
FROM Gold.Fact_Orders
WHERE review_score IS NOT NULL AND is_late_delivery = 0

UNION ALL

SELECT
    'Late Delivery Avg Rating' AS kpi_name,
    CAST(ROUND(AVG(CAST(review_score AS FLOAT)), 2) AS VARCHAR(50)) AS kpi_value,
    'Condition' AS context_name,
    'Late' AS context_value,
    'Average review score for late deliveries' AS context_meaning
FROM Gold.Fact_Orders
WHERE review_score IS NOT NULL AND is_late_delivery = 1;

GO

-- ============================================================================
-- Verify Views Created
-- ============================================================================
SELECT
    OBJECT_SCHEMA_NAME(object_id) AS schema_name,
    name AS view_name,
    GETDATE() AS created_at
FROM sys.objects
WHERE type = 'V' AND name IN ('vw_sales_dashboard_kpis', 'vw_markeing_dashboard_kpis', 'vw_customer_dashboard_kpis')
ORDER BY name;

GO
