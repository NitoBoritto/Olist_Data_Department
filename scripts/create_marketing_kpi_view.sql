-- Create vw_markeing_dashboard_kpis View
-- Provides marketing funnel KPIs for dashboard analytics
-- Note: View name matches existing typo "markeing" for consistency with API

USE [OlistDB];
GO

IF OBJECT_ID('Gold.vw_markeing_dashboard_kpis', 'V') IS NOT NULL
    DROP VIEW Gold.vw_markeing_dashboard_kpis;
GO

CREATE VIEW Gold.vw_markeing_dashboard_kpis AS
WITH funnel_stats AS (
    SELECT
        COUNT(DISTINCT mql_id) AS total_mqls,
        COUNT(DISTINCT CASE WHEN is_converted = 1 THEN seller_id END) AS sellers_acquired,
        COUNT(DISTINCT CASE WHEN is_converted = 0 THEN mql_id END) AS unconverted_leads,
        AVG(CAST(days_to_close AS FLOAT)) AS avg_days_to_close,
        ROUND(
            CAST(COUNT(DISTINCT CASE WHEN is_converted = 1 THEN seller_id END) AS FLOAT) / 
            NULLIF(COUNT(DISTINCT mql_id), 0) * 100,
            2
        ) AS conversion_rate_pct
    FROM Gold.Fact_Marketing_Funnel
)
SELECT 
    'Total MQLs' AS kpi_name,
    CAST(total_mqls AS FLOAT) AS kpi_value,
    'Total number of marketing qualified leads' AS kpi_meaning,
    'COUNT(DISTINCT mql_id)' AS sql_calculation_logic,
    'Leads' AS context_name,
    CAST(total_mqls AS VARCHAR(50)) AS context_value,
    'MQLs represent the top of the marketing funnel - initial qualified prospects.' AS context_meaning
FROM funnel_stats

UNION ALL

SELECT
    'Funnel Conversion Rate' AS kpi_name,
    conversion_rate_pct AS kpi_value,
    'Percentage of MQLs that convert to sellers' AS kpi_meaning,
    'COUNT(converted) / COUNT(total) * 100' AS sql_calculation_logic,
    'Conversion %' AS context_name,
    CAST(conversion_rate_pct AS VARCHAR(50)) AS context_value,
    CASE 
        WHEN conversion_rate_pct > 10 THEN 'Strong conversion efficiency - funnel is healthy.'
        WHEN conversion_rate_pct > 5 THEN 'Moderate conversion - standard industry range.'
        ELSE 'Low conversion rate - investigate bottlenecks in sales process.'
    END AS context_meaning
FROM funnel_stats

UNION ALL

SELECT
    'Average Days to Close' AS kpi_name,
    avg_days_to_close AS kpi_value,
    'Average sales cycle duration in days' AS kpi_meaning,
    'AVG(days_to_close) FROM Fact_Marketing_Funnel' AS sql_calculation_logic,
    'Days' AS context_name,
    CAST(CAST(avg_days_to_close AS INT) AS VARCHAR(50)) AS context_value,
    'Shorter cycles improve cash flow. Monitor for process improvements.' AS context_meaning
FROM funnel_stats

UNION ALL

SELECT
    'Sellers Acquired' AS kpi_name,
    CAST(sellers_acquired AS FLOAT) AS kpi_value,
    'Number of seller accounts successfully onboarded' AS kpi_meaning,
    'COUNT(DISTINCT seller_id WHERE is_converted = 1)' AS sql_calculation_logic,
    'Active Sellers' AS context_name,
    CAST(sellers_acquired AS VARCHAR(50)) AS context_value,
    'These sellers are active platform participants. Growth target: expand at 10-15% QoQ.' AS context_meaning
FROM funnel_stats

UNION ALL

SELECT
    'Unconverted Leads' AS kpi_name,
    CAST(unconverted_leads AS FLOAT) AS kpi_value,
    'Number of MQLs that did not convert to sellers' AS kpi_meaning,
    'COUNT(DISTINCT mql_id WHERE is_converted = 0)' AS sql_calculation_logic,
    'Leads at Risk' AS context_name,
    CAST(unconverted_leads AS VARCHAR(50)) AS context_value,
    'Analyze these leads to identify conversion barriers - product-market fit, pricing, or nurture gaps.' AS context_meaning
FROM funnel_stats;

GO

-- Verify the view was created successfully
SELECT TOP 5 
    kpi_name, 
    kpi_value, 
    context_name, 
    context_value 
FROM Gold.vw_markeing_dashboard_kpis;
