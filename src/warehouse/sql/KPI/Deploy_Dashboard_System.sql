CREATE OR ALTER PROCEDURE Gold.Deploy_Dashboard_System
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;

    -- ── Batch-level variables (مطابقة لـ Load_Gold) ──────────────────────
    DECLARE @Batch_Id          UNIQUEIDENTIFIER = NEWID();
    DECLARE @Batch_Start       DATETIME2        = SYSDATETIME();
    DECLARE @Table_Name        NVARCHAR(150);
    DECLARE @Load_Start        DATETIME2;
    DECLARE @Rows_Inserted     INT              = 0; -- Views مفيش rows، بس محتاجينه للـ pattern
    DECLARE @Target_Count      INT              = 0;

    BEGIN TRY

    PRINT '=================================================';
    PRINT '== Gold Views Deployment Started: ' + CONVERT(NVARCHAR, @Batch_Start, 120);
    PRINT '=================================================';

    -- ════════════════════════════════════════════════════════════════
    -- 1. Overview Dashboard View
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.vw_overview_dashboard_kpis'; SET @Load_Start = SYSDATETIME();
    EXEC('CREATE OR ALTER VIEW gold.vw_overview_dashboard_kpis AS
-- ============================================================
-- CTE 1: Yearly revenue aggregates
-- ============================================================
WITH yearly_revenue AS (
    SELECT
        d.year_number,
        SUM(o.total_payment)                                                    AS gmv,
        COUNT(DISTINCT o.order_id)                                              AS total_orders,
        SUM(o.total_payment) / COUNT(DISTINCT o.order_id)                       AS aov,
        AVG(CAST(o.review_score AS FLOAT))                                      AS avg_review,
        SUM(CASE WHEN o.is_late_delivery = 1 THEN 1 ELSE 0 END)                AS late_count,
        COUNT(o.order_id)                                                       AS all_orders,
        SUM(CASE WHEN o.order_status = ''canceled'' THEN 1 ELSE 0 END)           AS canceled_count,
        SUM(CASE WHEN o.review_score >= 4 THEN 1 ELSE 0 END)                  AS promoters,
        SUM(CASE WHEN o.review_score <= 2 THEN 1 ELSE 0 END)                  AS detractors,
        COUNT(DISTINCT o.customer_unique_id)                                   AS unique_customers
    FROM Gold.Fact_Orders o
    INNER JOIN Gold.Dim_Date d 
        ON o.purchase_date_key = d.date_key
    WHERE o.order_status NOT IN (''created'', ''approved'')
    GROUP BY d.year_number
),

-- ============================================================
-- Year-over-Year comparison
-- ============================================================
yearly_yoy AS (
    SELECT
        cur.year_number,
        cur.gmv                                                                 AS current_gmv,
        prev.gmv                                                                AS prior_gmv,
        CASE WHEN prev.gmv > 0
             THEN ROUND((cur.gmv - prev.gmv) / prev.gmv * 100, 1)
             ELSE NULL END                                                      AS gmv_yoy_pct,
        cur.total_orders,
        prev.total_orders                                                       AS prior_orders,
        cur.aov,
        prev.aov                                                                AS prior_aov,
        cur.avg_review,
        prev.avg_review                                                         AS prior_review,
        cur.late_count,
        cur.all_orders,
        CAST(cur.late_count AS FLOAT) / NULLIF(cur.all_orders, 0) * 100        AS late_rate,
        CAST(prev.late_count AS FLOAT) / NULLIF(prev.all_orders, 0) * 100      AS prior_late_rate,
        cur.canceled_count,
        CAST(cur.canceled_count AS FLOAT) / NULLIF(cur.all_orders, 0) * 100    AS cancel_rate,
        cur.promoters,
        cur.detractors,
        CAST(cur.promoters - cur.detractors AS FLOAT) / NULLIF(cur.all_orders, 0) * 100 AS nps_proxy,
        cur.unique_customers
    FROM yearly_revenue cur
    LEFT JOIN yearly_revenue prev 
        ON prev.year_number = cur.year_number - 1
),

-- ============================================================
-- Active sellers per year
-- ============================================================
yearly_sellers AS (
    SELECT
        d.year_number,
        COUNT(DISTINCT oi.seller_id) AS active_sellers
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Date d 
        ON oi.purchase_date_key = d.date_key
    GROUP BY d.year_number
),

-- ============================================================
-- Freight cost ratio per year
-- ============================================================
yearly_freight AS (
    SELECT
        d.year_number,
        ROUND(SUM(oi.freight_value) / NULLIF(SUM(oi.total_item_value), 0) * 100, 2) AS freight_pct
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Date d 
        ON oi.purchase_date_key = d.date_key
    GROUP BY d.year_number
),

-- ============================================================
-- Latest complete year (ديناميكي - مش هاردكود)
-- ============================================================
latest_year AS (
    SELECT MAX(year_number) AS max_year
    FROM yearly_revenue
    WHERE gmv > 1000000
)

-- ============================================================
-- KPI 1: GMV
-- ============================================================
SELECT
    ''Gross Merchandise Value (GMV)''                                           AS kpi_name,
    ROUND(y.current_gmv, 2)                                                    AS kpi_value,
    ''Total transaction value processed in '' + CAST(y.year_number AS VARCHAR)  AS kpi_meaning,
    ''SUM(Gold.Fact_Orders.total_payment)''                                     AS sql_calculation_logic,
    ''YoY Growth''                                                              AS context_name,
    CAST(y.gmv_yoy_pct AS VARCHAR(20)) + ''%''                                  AS context_value,
    CASE
        WHEN y.gmv_yoy_pct >= 20 THEN ''Strong growth of ''   + CAST(y.gmv_yoy_pct AS VARCHAR(20)) + ''%''
        WHEN y.gmv_yoy_pct >= 5  THEN ''Healthy growth of ''  + CAST(y.gmv_yoy_pct AS VARCHAR(20)) + ''%''
        WHEN y.gmv_yoy_pct >= 0  THEN ''Marginal growth of '' + CAST(y.gmv_yoy_pct AS VARCHAR(20)) + ''%''
        WHEN y.gmv_yoy_pct IS NULL THEN ''No prior year comparison''
        ELSE ''Decline of '' + CAST(ABS(y.gmv_yoy_pct) AS VARCHAR(20)) + ''%''
    END                                                                        AS context_meaning
FROM yearly_yoy y
INNER JOIN latest_year lyr ON y.year_number = lyr.max_year

UNION ALL

-- KPI 2: AOV
SELECT
    ''Average Order Value (AOV)'',
    ROUND(y.aov, 2),
    ''Average order value in '' + CAST(y.year_number AS VARCHAR),
    ''SUM(total_payment) / COUNT(DISTINCT order_id)'',
    ''AOV Change'',
    CAST(ROUND(y.aov - y.prior_aov, 2) AS VARCHAR(20)) + '' BRL'',
    CASE
        WHEN y.aov > y.prior_aov THEN ''AOV increased''
        WHEN y.aov < y.prior_aov THEN ''AOV decreased''
        ELSE ''Stable AOV''
    END
FROM yearly_yoy y
INNER JOIN latest_year lyr ON y.year_number = lyr.max_year

UNION ALL

-- KPI 3: Late Delivery
SELECT
    ''Late Delivery Rate'',
    ROUND(y.late_rate, 2),
    ''Late delivery percentage'',
    ''is_late_delivery / total orders'',
    ''Customer Impact'',
    NULL,
    CASE
        WHEN y.late_rate > 15 THEN ''Critical late rate''
        WHEN y.late_rate > 10 THEN ''High late rate''
        WHEN y.late_rate > 5  THEN ''Moderate late rate''
        ELSE ''Healthy''
    END
FROM yearly_yoy y
INNER JOIN latest_year lyr ON y.year_number = lyr.max_year

UNION ALL

-- KPI 4: NPS Proxy
SELECT
    ''Platform NPS Proxy'',
    ROUND(y.nps_proxy, 1),
    ''Customer satisfaction proxy'',
    ''(Promoters - Detractors) / total'',
    ''Sentiment'',
    NULL,
    CASE
        WHEN y.nps_proxy >= 50 THEN ''Excellent''
        WHEN y.nps_proxy >= 30 THEN ''Good''
        WHEN y.nps_proxy >= 0  THEN ''Neutral''
        ELSE ''Negative''
    END
FROM yearly_yoy y
INNER JOIN latest_year lyr ON y.year_number = lyr.max_year

UNION ALL

-- KPI 5: Cancellation Rate
SELECT
    ''Order Cancellation Rate'',
    ROUND(y.cancel_rate, 2),
    ''Canceled orders percentage'',
    ''canceled / total orders'',
    ''Revenue Risk'',
    NULL,
    CASE
        WHEN y.cancel_rate > 5 THEN ''High cancellation rate''
        WHEN y.cancel_rate > 2 THEN ''Moderate cancellation rate''
        ELSE ''Low cancellation rate''
    END
FROM yearly_yoy y
INNER JOIN latest_year lyr ON y.year_number = lyr.max_year

UNION ALL

-- KPI 6: Active Sellers
SELECT
    ''Active Sellers'',
    CAST(ys.active_sellers AS FLOAT),
    ''Number of active sellers'',
    ''COUNT(DISTINCT seller_id)'',
    ''Revenue per Seller'',
    ''R$'' + CAST(ROUND(y.current_gmv / NULLIF(ys.active_sellers, 0), 0) AS VARCHAR(20)),
    ''Seller base size and distribution''
FROM yearly_yoy y
INNER JOIN latest_year lyr ON y.year_number = lyr.max_year
INNER JOIN yearly_sellers ys ON ys.year_number = y.year_number

UNION ALL

-- KPI 7: Freight Ratio
SELECT
    ''Freight Cost Ratio'',
    yf.freight_pct,
    ''Freight cost % of revenue'',
    ''SUM(freight_value) / SUM(total_item_value)'',
    ''Logistics efficiency'',
    NULL,
    CASE
        WHEN yf.freight_pct > 15 THEN ''High freight cost''
        WHEN yf.freight_pct > 13 THEN ''Rising freight trend''
        ELSE ''Healthy freight level''
    END
FROM yearly_freight yf
INNER JOIN latest_year lyr ON yf.year_number = lyr.max_year
CROSS JOIN yearly_yoy y
WHERE y.year_number = lyr.max_year

UNION ALL

-- KPI 8: Customers
SELECT
    ''Total Unique Customers'',
    CAST(y.unique_customers AS FLOAT),
    ''Unique customers per year'',
    ''COUNT(DISTINCT customer_unique_id)'',
    ''Retention Insight'',
    NULL,
    ''Customer base size and retention analysis''
FROM yearly_yoy y
INNER JOIN latest_year lyr ON y.year_number = lyr.max_year;');

    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold_Views', @Table_Name, 'Gold.Deploy_Dashboard_System', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, 0, 0, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 2. Sales & Operational View
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.vw_sales_dashboard_kpis'; SET @Load_Start = SYSDATETIME();
    EXEC('CREATE OR ALTER VIEW gold.vw_sales_dashboard_kpis AS
WITH category_stats AS (
    SELECT
        p.category_name_en,
        SUM(oi.price)                                                           AS category_revenue,
        SUM(oi.freight_value)                                                   AS category_freight,
        SUM(oi.total_item_value)                                                AS category_total,
        COUNT(oi.order_item_key)                                                AS units_sold,
        AVG(CAST(o.review_score AS FLOAT))                                      AS avg_review,
        COUNT(DISTINCT oi.seller_id)                                            AS seller_count,
        ROUND(SUM(oi.freight_value) / NULLIF(SUM(oi.total_item_value), 0) * 100, 2) AS freight_pct
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Products p ON oi.product_id  = p.product_id
    INNER JOIN Gold.Fact_Orders  o ON oi.order_id    = o.order_id
    GROUP BY p.category_name_en
),
platform_total AS (
    SELECT SUM(category_revenue) AS total_rev FROM category_stats
),
category_ranked AS (
    SELECT *,
        RANK()      OVER (ORDER BY category_revenue DESC) AS revenue_rank,
        RANK()      OVER (ORDER BY avg_review DESC)       AS review_rank,
        RANK()      OVER (ORDER BY freight_pct DESC)      AS freight_rank,
        ROW_NUMBER() OVER (ORDER BY avg_review)           AS review_rn_asc  -- FIX: بدل RANK لتجنب الـ ties
    FROM category_stats
),
state_seller_stats AS (
    SELECT
        s.state,
        SUM(oi.total_item_value)                                                AS state_revenue,
        COUNT(DISTINCT oi.seller_id)                                            AS sellers_in_state,
        SUM(oi.total_item_value) / NULLIF(COUNT(DISTINCT oi.seller_id), 0)      AS revenue_per_seller,
        AVG(CAST(o.review_score AS FLOAT))                                      AS avg_review
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Sellers s ON oi.seller_id = s.seller_id
    INNER JOIN Gold.Fact_Orders o ON oi.order_id  = o.order_id
    GROUP BY s.state
),
state_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY state_revenue DESC) AS revenue_rn  -- FIX: ROW_NUMBER بدل RANK
    FROM state_seller_stats
),
payment_stats AS (
    SELECT
        primary_payment_type,
        COUNT(order_id)                                                         AS order_count,
        SUM(total_payment)                                                      AS payment_revenue,
        ROUND(CAST(COUNT(order_id) AS FLOAT) / SUM(COUNT(order_id)) OVER () * 100, 1) AS pct_of_orders
    FROM Gold.Fact_Orders
    WHERE order_status NOT IN (''created'', ''approved'')
    GROUP BY primary_payment_type
),
product_revenue AS (
    SELECT oi.product_id, SUM(oi.price) AS prod_rev
    FROM Gold.Fact_Order_Items oi
    GROUP BY oi.product_id
),
product_ranked AS (
    SELECT *,
        SUM(prod_rev) OVER ()                                                   AS total_rev,
        SUM(prod_rev) OVER (ORDER BY prod_rev DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)                   AS running_rev,
        ROW_NUMBER() OVER (ORDER BY prod_rev DESC)                              AS rn,
        COUNT(*) OVER ()                                                        AS total_products
    FROM product_revenue
),
pareto AS (
    SELECT
        COUNT(*)                                                                AS top20pct_products,
        ROUND(MAX(running_rev) / MAX(total_rev) * 100, 1)                       AS revenue_covered
    FROM product_ranked
    WHERE rn <= CAST(total_products * 0.2 AS INT)
),
-- FIX: استبدال year_number < 2019 الهاردكود بـ dynamic latest year
latest_data_year AS (
    SELECT MAX(year_number) AS max_year
    FROM Gold.Dim_Date
    WHERE year_number <= YEAR(GETDATE())
),
category_yearly AS (
    SELECT
        d.year_number,
        p.category_name_en,
        SUM(oi.price) AS rev
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Date d     ON oi.purchase_date_key = d.date_key
    INNER JOIN Gold.Dim_Products p ON oi.product_id        = p.product_id
    GROUP BY d.year_number, p.category_name_en
),
category_yoy AS (
    SELECT
        cur.category_name_en,
        cur.year_number,
        cur.rev                                                                 AS current_rev,
        prev.rev                                                                AS prior_rev,
        ROUND((cur.rev - prev.rev) / NULLIF(prev.rev, 0) * 100, 1)              AS yoy_pct
    FROM category_yearly cur
    LEFT JOIN category_yearly prev
        ON cur.category_name_en = prev.category_name_en
        AND prev.year_number    = cur.year_number - 1
    INNER JOIN latest_data_year ldy ON cur.year_number = ldy.max_year  -- FIX: ديناميكي
),
-- FIX: عزل أفضل category YoY بـ ROW_NUMBER لتجنب الـ ties وضمان row واحد
top_yoy AS (
    SELECT TOP 1 *
    FROM category_yoy
    WHERE prior_rev > 50000
    ORDER BY yoy_pct DESC
)

-- KPI 1: Top Revenue Category
SELECT
    ''Top Revenue Category''                                                     AS kpi_name,
    cr.category_revenue                                                        AS kpi_value,
    ''#1 revenue-generating product category on the platform''                  AS kpi_meaning,
    ''SUM(price) GROUP BY category''                                            AS sql_logic,
    ''Category Name''                                                           AS context_name,
    cr.category_name_en                                                        AS context_value,
    ''This category is the main revenue driver, representing ''
    + CAST(ROUND(cr.category_revenue / pt.total_rev * 100, 1) AS VARCHAR(20)) + ''% of total sales.'' AS context_meaning
FROM category_ranked cr
CROSS JOIN platform_total pt
WHERE cr.revenue_rank = 1

UNION ALL

-- KPI 2: Fastest Growing (YoY) -- FIX: بيجيب row واحد مضمون
SELECT
    ''Fastest-Growing Category (YoY)'',
    ty.current_rev,
    ''Highest revenue growth compared to previous year'',
    ''YoY Growth Formula'',
    ''Growth Rate'',
    CAST(ty.yoy_pct AS VARCHAR(20)) + ''%'',
    ty.category_name_en + '' is trending upward with '' + CAST(ty.yoy_pct AS VARCHAR(20)) + ''% growth.''
FROM top_yoy ty

UNION ALL

-- KPI 3: Logistics Risk (High Freight)
SELECT
    ''Highest Freight Burden'',
    cr.freight_pct,
    ''Logistics cost share of revenue'',
    ''SUM(freight) / SUM(total_value)'',
    ''Freight-to-Revenue %'',
    CAST(cr.freight_pct AS VARCHAR(20)) + ''%'',
    ''High freight costs in '' + cr.category_name_en + '' indicate margin risk due to heavy/bulky items.''
FROM category_ranked cr
WHERE cr.freight_rank = 1

UNION ALL

-- KPI 4: Lowest Customer Satisfaction -- FIX: ROW_NUMBER بدل MAX(review_rank)
SELECT
    ''Lowest Customer Satisfaction'',
    cr.avg_review,
    ''Category with poor customer feedback'',
    ''AVG(review_score)'',
    ''Avg Score'',
    cr.category_name_en + '' | '' + CAST(ROUND(cr.avg_review, 2) AS VARCHAR(20)),
    ''Poor satisfaction in this category risks brand damage. Quality audit recommended.''
FROM category_ranked cr
WHERE cr.review_rn_asc = 1

UNION ALL

-- KPI 5: Top Seller State -- FIX: ROW_NUMBER بدل RANK
SELECT
    ''Top Seller State (Revenue)'',
    sr.state_revenue,
    ''State with highest seller output'',
    ''SUM(revenue) GROUP BY state'',
    ''State + Sellers'',
    sr.state + '' | '' + CAST(sr.sellers_in_state AS VARCHAR(20)) + '' sellers'',
    sr.state + '' is the primary supply hub. Consider expanding recruitment to other states.''
FROM state_ranked sr
WHERE sr.revenue_rn = 1

UNION ALL

-- KPI 6: Pareto Concentration
SELECT
    ''Product Revenue Concentration'',
    pa.revenue_covered,
    ''% of revenue from top 20% products'',
    ''Pareto 80/20 Formula'',
    ''Top 20% Count'',
    CAST(pa.top20pct_products AS VARCHAR(20)) + '' products'',
    ''Platform depends heavily on these '' + CAST(pa.top20pct_products AS VARCHAR(20)) + '' core products for revenue.''
FROM pareto pa;');

    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold_Views', @Table_Name, 'Gold.Deploy_Dashboard_System', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, 0, 0, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 3. Marketing Funnel View
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.vw_marketing_dashboard_kpis'; SET @Load_Start = SYSDATETIME();
    EXEC('CREATE OR ALTER VIEW gold.vw_marketing_dashboard_kpis AS
WITH funnel_overall AS (
    SELECT
        COUNT(mql_id)                                                           AS total_mqls,
        SUM(CASE WHEN is_converted = 1 THEN 1 ELSE 0 END)                      AS total_converted,
        ROUND(CAST(SUM(CASE WHEN is_converted=1 THEN 1 ELSE 0 END) AS FLOAT)
              / NULLIF(COUNT(mql_id), 0) * 100, 2)                             AS overall_conversion_rate,
        ROUND(AVG(CASE WHEN is_converted = 1 THEN CAST(days_to_close AS FLOAT) ELSE NULL END), 1) AS avg_days_to_close
    FROM Gold.Fact_Marketing_Funnel
),
channel_stats AS (
    SELECT
        lead_origin,
        COUNT(mql_id)                                                           AS mqls,
        SUM(CASE WHEN is_converted = 1 THEN 1 ELSE 0 END)                      AS converted,
        ROUND(CAST(SUM(CASE WHEN is_converted=1 THEN 1 ELSE 0 END) AS FLOAT)
              / NULLIF(COUNT(mql_id), 0) * 100, 2)                             AS conv_rate,
        ROUND(AVG(CASE WHEN is_converted = 1 THEN CAST(days_to_close AS FLOAT) ELSE NULL END), 1) AS avg_close_days
    FROM Gold.Fact_Marketing_Funnel
    GROUP BY lead_origin
),
channel_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY conv_rate DESC)    AS conv_rn_desc,  -- FIX: ROW_NUMBER
        ROW_NUMBER() OVER (ORDER BY avg_close_days)    AS speed_rn_asc,  -- FIX: ROW_NUMBER
        ROW_NUMBER() OVER (ORDER BY conv_rate)         AS conv_rn_asc,   -- FIX: ROW_NUMBER
        RANK()       OVER (ORDER BY mqls DESC)         AS volume_rank
    FROM channel_stats
    WHERE mqls >= 50
),
mktg_revenue AS (
    SELECT
        s.came_from_marketing,
        SUM(oi.total_item_value)                                                AS total_revenue,
        COUNT(DISTINCT oi.seller_id)                                            AS seller_count,
        SUM(oi.total_item_value) / NULLIF(COUNT(DISTINCT oi.seller_id), 0)     AS revenue_per_seller
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Dim_Sellers s ON oi.seller_id = s.seller_id
    GROUP BY s.came_from_marketing
),
sdr_stats AS (
    SELECT
        sdr_id,
        COUNT(mql_id)                                                           AS leads_handled,
        SUM(CASE WHEN is_converted = 1 THEN 1 ELSE 0 END)                      AS deals_closed,
        ROUND(CAST(SUM(CASE WHEN is_converted=1 THEN 1 ELSE 0 END) AS FLOAT)
              / NULLIF(COUNT(mql_id), 0) * 100, 2)                             AS conv_rate
    FROM Gold.Fact_Marketing_Funnel
    WHERE sdr_id IS NOT NULL
    GROUP BY sdr_id
    HAVING COUNT(mql_id) >= 10
),
sdr_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY conv_rate DESC) AS rank_asc,  -- FIX: ROW_NUMBER
        COUNT(*) OVER ()                            AS total_sdrs
    FROM sdr_stats
),
monthly_funnel AS (
    SELECT
        d.year_number,
        d.month_number,
        COUNT(f.mql_id)                                                         AS monthly_mqls,
        SUM(CASE WHEN f.is_converted = 1 THEN 1 ELSE 0 END)                    AS monthly_converted
    FROM Gold.Fact_Marketing_Funnel f
    INNER JOIN Gold.Dim_Date d ON f.first_contact_date_key = d.date_key
    GROUP BY d.year_number, d.month_number
),
mf_lagged AS (
    SELECT *,
        LAG(monthly_mqls, 1) OVER (ORDER BY year_number, month_number) AS prev_mqls
    FROM monthly_funnel
),
latest_mf AS (
    SELECT TOP 1 * FROM mf_lagged ORDER BY year_number DESC, month_number DESC
)

-- KPI 1: Overall Conversion Rate
SELECT
    ''Seller Acquisition Conversion Rate''                                       AS kpi_name,
    f.overall_conversion_rate                                                  AS kpi_value,
    ''Percentage of MQLs that successfully became active sellers''              AS kpi_meaning,
    ''SUM(is_converted=1) / COUNT(mql_id) * 100''                              AS sql_calculation_logic,
    ''Total Pipeline''                                                          AS context_name,
    CAST(f.total_mqls AS VARCHAR(20)) + '' MQLs → '' + CAST(f.total_converted AS VARCHAR(20)) + '' Sellers'' AS context_value,
    CASE
        WHEN f.overall_conversion_rate >= 15 THEN ''Strong B2B conversion rate. Lead quality is high.''
        WHEN f.overall_conversion_rate >= 10 THEN ''Good conversion rate — near industry B2B benchmark of 10-15%.''
        WHEN f.overall_conversion_rate >= 5  THEN ''Below average. Investigate SDR follow-up quality.''
        ELSE ''Critical — most leads not converting. Full funnel audit required.''
    END                                                                        AS context_meaning
FROM funnel_overall f

UNION ALL

-- KPI 2: Best-Converting Channel -- FIX: ROW_NUMBER بدل RANK
SELECT
    ''Best-Converting Acquisition Channel'',
    cr.conv_rate,
    ''Acquisition channel with the highest MQL-to-seller conversion rate'',
    ''SUM(converted) / COUNT(mql_id) * 100 GROUP BY lead_origin WHERE mqls >= 50'',
    ''Channel + Volume'',
    cr.lead_origin + '' | '' + CAST(cr.mqls AS VARCHAR(20)) + '' leads'',
    cr.lead_origin + '' converts at '' + CAST(cr.conv_rate AS VARCHAR(20)) + ''% — highest of all channels with sufficient volume.''
FROM channel_ranked cr
WHERE cr.conv_rn_desc = 1

UNION ALL

-- KPI 3: Fastest Closing Channel -- FIX: ROW_NUMBER
SELECT
    ''Fastest-Closing Acquisition Channel'',
    cr.avg_close_days,
    ''Channel where converted sellers reach active status in the shortest time'',
    ''AVG(days_to_close) WHERE is_converted=1 GROUP BY lead_origin'',
    ''Channel + Speed'',
    cr.lead_origin + '' | Avg '' + CAST(cr.avg_close_days AS VARCHAR(20)) + '' days to close'',
    cr.lead_origin + '' closes in avg '' + CAST(cr.avg_close_days AS VARCHAR(20)) + '' days — fastest of all channels.''
FROM channel_ranked cr
WHERE cr.speed_rn_asc = 1

UNION ALL

-- KPI 4: Lowest-Converting Channel -- FIX: ROW_NUMBER
SELECT
    ''Lowest-Converting Acquisition Channel'',
    cr.conv_rate,
    ''Channel generating the most leads but converting the fewest'',
    ''SUM(converted) / COUNT(mql_id) * 100 GROUP BY lead_origin, lowest rate'',
    ''Channel + Waste'',
    cr.lead_origin + '' | '' + CAST(cr.mqls AS VARCHAR(20)) + '' leads, '' + CAST(cr.converted AS VARCHAR(20)) + '' converted'',
    cr.lead_origin + '' generates '' + CAST(cr.mqls AS VARCHAR(20)) + '' leads but converts only ''
    + CAST(cr.conv_rate AS VARCHAR(20)) + ''%. Consider reducing budget here.''
FROM channel_ranked cr
WHERE cr.conv_rn_asc = 1

UNION ALL

-- KPI 5: Marketing-Sourced Seller Revenue
SELECT
    ''Marketing-Sourced Seller Revenue'',
    mr_mktg.total_revenue,
    ''Total revenue generated by sellers acquired through the marketing funnel'',
    ''SUM(total_item_value) WHERE came_from_marketing = 1'',
    ''vs Organic Sellers'',
    ''Marketing: R$'' + CAST(ROUND(mr_mktg.total_revenue, 0) AS VARCHAR(20))
        + '' | Organic: R$'' + CAST(ROUND(mr_organic.total_revenue, 0) AS VARCHAR(20)),
    ''Marketing sellers: '' + CAST(mr_mktg.seller_count AS VARCHAR(20))
    + '' sellers, avg R$'' + CAST(ROUND(mr_mktg.revenue_per_seller, 0) AS VARCHAR(20))
    + '' each vs R$'' + CAST(ROUND(mr_organic.revenue_per_seller, 0) AS VARCHAR(20)) + '' for organic sellers.''
FROM mktg_revenue mr_mktg
CROSS JOIN mktg_revenue mr_organic
WHERE mr_mktg.came_from_marketing = 1
  AND mr_organic.came_from_marketing = 0

UNION ALL

-- KPI 6: Avg Days to Close
SELECT
    ''Average Sales Cycle Length'',
    f.avg_days_to_close,
    ''Average days from first contact to seller activation'',
    ''AVG(days_to_close) WHERE is_converted=1'',
    ''Cycle Length'',
    CAST(f.avg_days_to_close AS VARCHAR(20)) + '' days average'',
    ''Avg '' + CAST(f.avg_days_to_close AS VARCHAR(20)) + '' days to close. Reducing cycle length increases effective SDR capacity.''
FROM funnel_overall f

UNION ALL

-- KPI 7: Top SDR -- FIX: ROW_NUMBER
SELECT
    ''Top SDR Conversion Rate'',
    sr.conv_rate,
    ''Highest individual SDR conversion rate'',
    ''SUM(is_converted) / COUNT(mql_id) * 100 GROUP BY sdr_id'',
    ''SDR ID + Deals'',
    ''SDR: '' + sr.sdr_id + '' | '' + CAST(sr.deals_closed AS VARCHAR(20)) + '' deals / '' + CAST(sr.leads_handled AS VARCHAR(20)) + '' leads'',
    ''Top SDR converts at '' + CAST(sr.conv_rate AS VARCHAR(20)) + ''%. Document their approach as a playbook for the team.''
FROM sdr_ranked sr
WHERE sr.rank_asc = 1

UNION ALL

-- KPI 8: Unconverted Lead Volume
SELECT
    ''Unconverted Lead Volume'',
    CAST(f.total_mqls - f.total_converted AS FLOAT),
    ''Leads that never became active sellers'',
    ''COUNT(mql_id) - SUM(is_converted=1)'',
    ''Cost of Inaction'',
    CAST(f.total_mqls - f.total_converted AS VARCHAR(20)) + '' leads lost'',
    CAST(f.total_mqls - f.total_converted AS VARCHAR(20)) + '' leads did not convert. ''
    + ''A 5% improvement would add '' + CAST(CAST((f.total_mqls - f.total_converted) * 0.05 AS INT) AS VARCHAR(20)) + '' new sellers.''
FROM funnel_overall f;');

    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold_Views', @Table_Name, 'Gold.Deploy_Dashboard_System', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, 0, 0, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 4. Customer Behavior View
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.vw_customer_dashboard_kpis'; SET @Load_Start = SYSDATETIME();
    EXEC('CREATE OR ALTER VIEW gold.vw_customer_dashboard_kpis AS
WITH customer_history AS (
    SELECT
        o.customer_unique_id,
        c.state,
        COUNT(DISTINCT o.order_id)                                              AS order_count,
        SUM(o.total_payment)                                                    AS lifetime_spend,
        AVG(CAST(o.review_score AS FLOAT))                                      AS avg_review,
        MIN(d.full_date)                                                        AS first_order_date,
        MAX(d.full_date)                                                        AS last_order_date,
        SUM(CASE WHEN o.is_late_delivery = 1 THEN 1 ELSE 0 END)                AS late_orders_received,
        SUM(CASE WHEN o.review_score >= 4 THEN 1 ELSE 0 END)                   AS promoter_orders,
        SUM(CASE WHEN o.review_score <= 2 THEN 1 ELSE 0 END)                   AS detractor_orders
    FROM Gold.Fact_Orders o
    INNER JOIN Gold.Dim_Customers c ON o.customer_unique_id = c.customer_unique_id
    INNER JOIN Gold.Dim_Date d      ON o.purchase_date_key  = d.date_key
    WHERE o.order_status = ''delivered''
    GROUP BY o.customer_unique_id, c.state
),
repeat_analysis AS (
    SELECT
        COUNT(*)                                                                AS total_customers,
        SUM(CASE WHEN order_count = 1  THEN 1 ELSE 0 END)                      AS single_purchase,
        SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END)                      AS repeat_customers,
        SUM(CASE WHEN order_count >= 2 THEN lifetime_spend ELSE 0 END)         AS repeat_revenue,
        SUM(lifetime_spend)                                                     AS total_revenue,
        AVG(lifetime_spend)                                                     AS avg_ltv
    FROM customer_history
),
state_kpis AS (
    SELECT
        state,
        COUNT(DISTINCT customer_unique_id)                                      AS customer_count,
        SUM(lifetime_spend)                                                     AS state_revenue,
        AVG(lifetime_spend)                                                     AS avg_customer_ltv,
        AVG(avg_review)                                                         AS state_avg_review,
        AVG(CAST(order_count AS FLOAT))                                         AS avg_orders_per_customer,
        SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(*), 0)                                               AS repeat_rate,
        SUM(late_orders_received) * 100.0
            / NULLIF(SUM(order_count), 0)                                       AS late_delivery_rate
    FROM customer_history
    GROUP BY state
),
state_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY customer_count DESC)    AS cust_rn,     -- FIX: ROW_NUMBER
        ROW_NUMBER() OVER (ORDER BY avg_customer_ltv DESC)  AS ltv_rn,      -- FIX: ROW_NUMBER
        ROW_NUMBER() OVER (ORDER BY repeat_rate DESC)       AS retention_rn, -- FIX: ROW_NUMBER
        ROW_NUMBER() OVER (ORDER BY late_delivery_rate DESC) AS late_rn     -- FIX: ROW_NUMBER
    FROM state_kpis
    WHERE customer_count >= 100
),
delivery_impact AS (
    SELECT
        AVG(CASE WHEN o.is_late_delivery = 0 THEN CAST(o.review_score AS FLOAT) ELSE NULL END) AS ontime_review,
        AVG(CASE WHEN o.is_late_delivery = 1 THEN CAST(o.review_score AS FLOAT) ELSE NULL END) AS late_review,
        SUM(CASE WHEN o.is_late_delivery = 1 THEN 1 ELSE 0 END)                                AS late_orders,
        COUNT(*)                                                                                AS total_orders
    FROM Gold.Fact_Orders o
    WHERE o.review_score IS NOT NULL
      AND o.order_status = ''delivered''
),
quartile_analysis AS (
    SELECT
        NTILE(4) OVER (ORDER BY lifetime_spend) AS spend_quartile,
        lifetime_spend,
        order_count
    FROM customer_history
),
quartile_summary AS (
    SELECT
        spend_quartile,
        COUNT(*)                                AS customers,
        SUM(lifetime_spend)                     AS quartile_revenue,
        AVG(lifetime_spend)                     AS avg_spend,
        SUM(SUM(lifetime_spend)) OVER ()        AS total_rev
    FROM quartile_analysis
    GROUP BY spend_quartile
)

-- KPI 1: Repeat Customer Rate
SELECT
    ''Repeat Customer Rate''                                                     AS kpi_name,
    ROUND(ra.repeat_customers * 100.0 / NULLIF(ra.total_customers, 0), 2)     AS kpi_value,
    ''Percentage of customers who placed more than one order''                  AS kpi_meaning,
    ''SUM(customers with order_count>1) / COUNT(all customers) * 100''          AS sql_calculation_logic,
    ''Revenue Impact of Repeat Buyers''                                         AS context_name,
    CAST(ra.repeat_customers AS VARCHAR(20)) + '' repeat customers | R$''
        + CAST(ROUND(ra.repeat_revenue, 0) AS VARCHAR(20)) + '' revenue''      AS context_value,
    ''Only '' + CAST(ROUND(ra.repeat_customers * 100.0 / NULLIF(ra.total_customers, 0), 1) AS VARCHAR(20))
    + ''% of customers purchase more than once. Increasing repeat rate is the highest-ROI retention lever.'' AS context_meaning
FROM repeat_analysis ra

UNION ALL

-- KPI 2: Customer LTV
SELECT
    ''Average Customer Lifetime Value (LTV)'',
    ROUND(ra.avg_ltv, 2),
    ''Average total revenue generated per unique customer'',
    ''SUM(total_payment) / COUNT(DISTINCT customer_unique_id)'',
    ''LTV Insight'',
    ''Avg LTV: R$'' + CAST(ROUND(ra.avg_ltv, 2) AS VARCHAR(20)),
    ''Average LTV is R$'' + CAST(ROUND(ra.avg_ltv, 2) AS VARCHAR(20))
    + ''. Heavily diluted by single-purchase customers. Growing repeat rate is the primary LTV lever.''
FROM repeat_analysis ra

UNION ALL

-- KPI 3: Top Customer State -- FIX: ROW_NUMBER
SELECT
    ''Largest Customer Market (by volume)'',
    CAST(sr.customer_count AS FLOAT),
    ''State with the highest number of unique customers'',
    ''COUNT(DISTINCT customer_unique_id) GROUP BY state ORDER BY DESC'',
    ''State + Market Share'',
    sr.state + '' | '' + CAST(sr.customer_count AS VARCHAR(20)) + '' customers'',
    sr.state + '' is the largest customer market with '' + CAST(sr.customer_count AS VARCHAR(20)) + '' customers.''
FROM state_ranked sr
WHERE sr.cust_rn = 1

UNION ALL

-- KPI 4: Highest LTV State -- FIX: ROW_NUMBER
SELECT
    ''Highest LTV Customer State'',
    sr.avg_customer_ltv,
    ''State where customers spend the most per person on average'',
    ''SUM(lifetime_spend) / COUNT(DISTINCT customer_unique_id) GROUP BY state'',
    ''LTV + State'',
    sr.state + '' | Avg LTV R$'' + CAST(ROUND(sr.avg_customer_ltv, 2) AS VARCHAR(20)),
    sr.state + '' customers have the highest average LTV at R$'' + CAST(ROUND(sr.avg_customer_ltv, 2) AS VARCHAR(20)) + ''.''
FROM state_ranked sr
WHERE sr.ltv_rn = 1

UNION ALL

-- KPI 5: Worst Experience State -- FIX: ROW_NUMBER
SELECT
    ''Worst Customer Experience State (Late Delivery)'',
    ROUND(sr.late_delivery_rate, 1),
    ''State with the highest late delivery rate'',
    ''SUM(is_late_delivery=1) / COUNT(orders) * 100 GROUP BY customer state'',
    ''State + Late Rate'',
    sr.state + '' | '' + CAST(ROUND(sr.late_delivery_rate, 1) AS VARCHAR(20)) + ''% late rate'',
    sr.state + '' has the highest late delivery rate at ''
    + CAST(ROUND(sr.late_delivery_rate, 1) AS VARCHAR(20)) + ''%. Negotiate SLA improvement with last-mile carriers immediately.''
FROM state_ranked sr
WHERE sr.late_rn = 1

UNION ALL

-- KPI 6: Delivery Quality → Satisfaction Correlation
SELECT
    ''Late Delivery Impact on Review Score'',
    ROUND(di.ontime_review - di.late_review, 2),
    ''Difference in avg review score between on-time and late deliveries'',
    ''AVG(review_score) WHERE is_late=0 MINUS AVG(review_score) WHERE is_late=1'',
    ''On-Time vs Late Reviews'',
    ''On-time: '' + CAST(ROUND(di.ontime_review, 2) AS VARCHAR(20)) + ''/5 | Late: '' + CAST(ROUND(di.late_review, 2) AS VARCHAR(20)) + ''/5'',
    ''Late deliveries produce avg '' + CAST(ROUND(di.late_review, 2) AS VARCHAR(20))
    + '' vs '' + CAST(ROUND(di.ontime_review, 2) AS VARCHAR(20))
    + '' for on-time — a gap of '' + CAST(ROUND(di.ontime_review - di.late_review, 2) AS VARCHAR(20)) + '' points.''
FROM delivery_impact di

UNION ALL

-- KPI 7: Top 25% Customer Contribution
SELECT
    ''Top 25% Customer Revenue Contribution'',
    ROUND(qs.quartile_revenue * 100.0 / NULLIF(qs.total_rev, 0), 1),
    ''Revenue % from top 25% of customers by spend'',
    ''NTILE(4) on lifetime_spend, SUM revenue for top quartile'',
    ''Customers in Top Quartile'',
    CAST(qs.customers AS VARCHAR(20)) + '' customers | R$'' + CAST(ROUND(qs.quartile_revenue, 0) AS VARCHAR(20)),
    ''Top 25% of customers contribute ''
    + CAST(ROUND(qs.quartile_revenue * 100.0 / NULLIF(qs.total_rev, 0), 1) AS VARCHAR(20))
    + ''% of all platform revenue. A VIP program would protect this critical revenue base.''
FROM quartile_summary qs
WHERE qs.spend_quartile = 4

UNION ALL

-- KPI 8: Platform NPS Proxy
SELECT
    ''Customer Satisfaction Score (NPS Proxy)'',
    ROUND((SUM(CAST(promoter_orders AS FLOAT)) - SUM(CAST(detractor_orders AS FLOAT)))
          / NULLIF(SUM(CAST(order_count AS FLOAT)), 0) * 100, 1),
    ''NPS estimate: (4-5 star orders − 1-2 star orders) / total × 100'',
    ''(SUM(review>=4) - SUM(review<=2)) / COUNT(*) * 100'',
    ''Promoters vs Detractors'',
    ''Promoters: '' + CAST(ROUND(SUM(CAST(promoter_orders AS FLOAT)) / NULLIF(SUM(CAST(order_count AS FLOAT)),0) * 100, 1) AS VARCHAR(20))
    + ''% | Detractors: '' + CAST(ROUND(SUM(CAST(detractor_orders AS FLOAT)) / NULLIF(SUM(CAST(order_count AS FLOAT)),0) * 100, 1) AS VARCHAR(20)) + ''%'',
    ''NPS proxy calculated dynamically from actual review distribution.''
FROM customer_history;');

    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold_Views', @Table_Name, 'Gold.Deploy_Dashboard_System', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, 0, 0, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- Batch Close (مطابق لـ Load_Gold تمامًا)
    -- ════════════════════════════════════════════════════════════════
    UPDATE [Audit].[ETL_Log]
    SET    Batch_End_Time      = SYSDATETIME(),
           Batch_Duration_Sec  = DATEDIFF(SECOND, @Batch_Start, SYSDATETIME())
    WHERE  Batch_Id = @Batch_Id;  -- FIX: إزالة AND Table_Name IS NULL

    PRINT '=================================================';
    PRINT '      All Gold Views Deployed Successfully';
    PRINT '=================================================';

    END TRY
    BEGIN CATCH
        -- FIX: UPDATE الـ batch أولاً (زي Load_Gold) ثم INSERT الـ error
        UPDATE [Audit].[ETL_Log]
        SET    Batch_End_Time      = SYSDATETIME(),
               Batch_Duration_Sec  = DATEDIFF(SECOND, @Batch_Start, SYSDATETIME())
        WHERE  Batch_Id = @Batch_Id AND Batch_End_Time IS NULL;

        INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Status, Error_Message, Error_Number, Error_State)
        VALUES (@Batch_Id, 'Gold_Views', @Table_Name, 'Gold.Deploy_Dashboard_System', 'FAILED', ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_STATE());

        THROW;
    END CATCH
END;
GO