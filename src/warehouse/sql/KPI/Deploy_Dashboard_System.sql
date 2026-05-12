CREATE OR ALTER PROCEDURE Gold.Deploy_Dashboard_System
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;

    -- ── Batch-level variables ──────────────────────
    DECLARE @Batch_Id          UNIQUEIDENTIFIER = NEWID();
    DECLARE @Batch_Start       DATETIME2        = SYSDATETIME();
    DECLARE @Table_Name        NVARCHAR(150);
    DECLARE @Load_Start        DATETIME2;
    DECLARE @Rows_Inserted     INT              = 0;
    DECLARE @Target_Count      INT              = 0;

    BEGIN TRY

    PRINT '=================================================';
    PRINT '== Gold Views Deployment Started: ' + CONVERT(NVARCHAR, @Batch_Start, 120);
    PRINT '=================================================';

    -- ════════════════════════════════════════════════════════════════
    -- 1. Overview Dashboard View (Accurate Denominators)
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.vw_overview_dashboard_kpis'; SET @Load_Start = SYSDATETIME();
    EXEC('CREATE OR ALTER VIEW gold.vw_overview_dashboard_kpis AS
WITH yearly_revenue AS (
    SELECT
        d.year_number,
        
        -- 1. المبيعات (نستبعد الملغي والغير معتمد)
        SUM(CASE WHEN o.order_status NOT IN (''created'', ''approved'', ''canceled'', ''unavailable'') THEN o.total_payment ELSE 0 END) AS gmv,
        SUM(CASE WHEN o.order_status NOT IN (''created'', ''approved'', ''canceled'', ''unavailable'') THEN 1 ELSE 0 END) AS valid_orders,
        
        -- 2. التشغيل والرضا (نحسب على اللي وصل للعميل فعلياً)
        SUM(CASE WHEN o.order_status = ''delivered'' AND o.is_late_delivery = 1 THEN 1 ELSE 0 END) AS late_count,
        SUM(CASE WHEN o.order_status = ''delivered'' THEN 1 ELSE 0 END) AS delivered_orders,
        SUM(CASE WHEN o.order_status = ''delivered'' AND o.review_score >= 4 THEN 1 ELSE 0 END) AS promoters,
        SUM(CASE WHEN o.order_status = ''delivered'' AND o.review_score <= 2 THEN 1 ELSE 0 END) AS detractors,
        
        -- 3. الإلغاء (نحسبه من الإجمالي الكلي اللي دخل السيستم)
        SUM(CASE WHEN o.order_status = ''canceled'' THEN 1 ELSE 0 END) AS canceled_count,
        COUNT(o.order_id) AS total_system_orders,
        
        COUNT(DISTINCT CASE WHEN o.order_status NOT IN (''canceled'', ''unavailable'') THEN o.customer_unique_id END) AS unique_customers
    FROM Gold.Fact_Orders o
    INNER JOIN Gold.Dim_Date d ON o.purchase_date_key = d.date_key
    GROUP BY d.year_number
),
yearly_yoy AS (
    SELECT
        cur.year_number,
        cur.gmv AS current_gmv,
        prev.gmv AS prior_gmv,
        CASE WHEN prev.gmv > 0 THEN ROUND((cur.gmv - prev.gmv) / prev.gmv * 100, 1) ELSE NULL END AS gmv_yoy_pct,
        cur.gmv / NULLIF(cur.valid_orders, 0) AS aov,
        prev.gmv / NULLIF(prev.valid_orders, 0) AS prior_aov,
        CAST(cur.late_count AS FLOAT) / NULLIF(cur.delivered_orders, 0) * 100 AS late_rate,
        CAST(cur.canceled_count AS FLOAT) / NULLIF(cur.total_system_orders, 0) * 100 AS cancel_rate,
        CAST(cur.promoters - cur.detractors AS FLOAT) / NULLIF(cur.delivered_orders, 0) * 100 AS nps_proxy,
        cur.unique_customers
    FROM yearly_revenue cur
    LEFT JOIN yearly_revenue prev ON prev.year_number = cur.year_number - 1
),
yearly_sellers AS (
    SELECT d.year_number, COUNT(DISTINCT oi.seller_id) AS active_sellers
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Fact_Orders o ON oi.order_id = o.order_id
    INNER JOIN Gold.Dim_Date d ON o.purchase_date_key = d.date_key
    WHERE o.order_status NOT IN (''created'', ''approved'', ''canceled'', ''unavailable'')
    GROUP BY d.year_number
),
yearly_freight AS (
    SELECT d.year_number, ROUND(SUM(oi.freight_value) / NULLIF(SUM(oi.total_item_value), 0) * 100, 2) AS freight_pct
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Fact_Orders o ON oi.order_id = o.order_id
    INNER JOIN Gold.Dim_Date d ON o.purchase_date_key = d.date_key
    WHERE o.order_status NOT IN (''created'', ''approved'', ''canceled'', ''unavailable'')
    GROUP BY d.year_number
)
SELECT 
    y.year_number, ''Gross Merchandise Value (GMV)'' AS kpi_name, ROUND(y.current_gmv, 2) AS kpi_value, 
    ''Total transaction value processed'' AS kpi_meaning, ''SUM(total_payment)'' AS sql_calculation_logic,
    ''YoY Growth'' AS context_name, CAST(y.gmv_yoy_pct AS VARCHAR(20)) + ''%'' AS context_value,
    CASE WHEN y.gmv_yoy_pct >= 20 THEN ''Strong growth'' WHEN y.gmv_yoy_pct >= 0 THEN ''Marginal growth'' 
         WHEN y.gmv_yoy_pct IS NULL THEN ''No prior year comparison'' ELSE ''Decline'' END AS context_meaning
FROM yearly_yoy y
UNION ALL
SELECT y.year_number, ''Average Order Value (AOV)'', ROUND(y.aov, 2), ''Average order value'', ''SUM/COUNT'', ''AOV Change'', CAST(ROUND(y.aov - y.prior_aov, 2) AS VARCHAR(20)) + '' BRL'', CASE WHEN y.aov > y.prior_aov THEN ''AOV increased'' WHEN y.aov < y.prior_aov THEN ''AOV decreased'' ELSE ''Stable AOV'' END FROM yearly_yoy y
UNION ALL
SELECT y.year_number, ''Late Delivery Rate'', ROUND(y.late_rate, 2), ''Late delivery percentage (Delivered only)'', ''is_late / delivered_orders'', ''Customer Impact'', NULL, CASE WHEN y.late_rate > 10 THEN ''High late rate'' ELSE ''Healthy'' END FROM yearly_yoy y
UNION ALL
SELECT y.year_number, ''Platform NPS Proxy'', ROUND(y.nps_proxy, 1), ''Customer satisfaction proxy'', ''Promoters - Detractors'', ''Sentiment'', NULL, CASE WHEN y.nps_proxy >= 30 THEN ''Good'' WHEN y.nps_proxy >= 0 THEN ''Neutral'' ELSE ''Negative'' END FROM yearly_yoy y
UNION ALL
SELECT y.year_number, ''Order Cancellation Rate'', ROUND(y.cancel_rate, 2), ''Canceled orders percentage'', ''canceled / all_system_orders'', ''Revenue Risk'', NULL, CASE WHEN y.cancel_rate > 2 THEN ''Moderate cancellation rate'' ELSE ''Low cancellation rate'' END FROM yearly_yoy y
UNION ALL
SELECT y.year_number, ''Active Sellers'', CAST(ys.active_sellers AS FLOAT), ''Number of active sellers'', ''COUNT(seller_id)'', ''Revenue per Seller'', ''R$'' + CAST(ROUND(y.current_gmv / NULLIF(ys.active_sellers, 0), 0) AS VARCHAR(20)), ''Seller base size'' FROM yearly_yoy y INNER JOIN yearly_sellers ys ON ys.year_number = y.year_number
UNION ALL
SELECT y.year_number, ''Freight Cost Ratio'', yf.freight_pct, ''Freight cost % of revenue'', ''freight / total_item_value'', ''Logistics efficiency'', NULL, CASE WHEN yf.freight_pct > 15 THEN ''High freight cost'' ELSE ''Healthy freight level'' END FROM yearly_freight yf INNER JOIN yearly_yoy y ON y.year_number = yf.year_number
UNION ALL
SELECT y.year_number, ''Total Unique Customers'', CAST(y.unique_customers AS FLOAT), ''Unique customers per year'', ''COUNT(customer_unique_id)'', ''Retention Insight'', NULL, ''Customer base size'' FROM yearly_yoy y;');

    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold_Views', @Table_Name, 'Gold.Deploy_Dashboard_System', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, 0, 0, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 2. Sales & Operational View (Filtered for accurate items)
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.vw_sales_dashboard_kpis'; SET @Load_Start = SYSDATETIME();
    EXEC('CREATE OR ALTER VIEW gold.vw_sales_dashboard_kpis AS
WITH category_stats AS (
    SELECT
        d.year_number, p.category_name_en,
        SUM(oi.price) AS category_revenue,
        SUM(oi.freight_value) AS category_freight,
        SUM(oi.total_item_value) AS category_total,
        COUNT(oi.order_item_key) AS units_sold,
        COUNT(DISTINCT oi.seller_id) AS seller_count,
        ROUND(SUM(oi.freight_value) / NULLIF(SUM(oi.total_item_value), 0) * 100, 2) AS freight_pct,
        AVG(CASE WHEN o.order_status = ''delivered'' THEN CAST(o.review_score AS FLOAT) ELSE NULL END) AS avg_review
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Fact_Orders o ON oi.order_id = o.order_id
    INNER JOIN Gold.Dim_Date d ON o.purchase_date_key = d.date_key 
    INNER JOIN Gold.Dim_Products p ON oi.product_id = p.product_id
    WHERE o.order_status NOT IN (''created'', ''approved'', ''canceled'', ''unavailable'') 
    GROUP BY d.year_number, p.category_name_en
),
platform_total AS (
    SELECT year_number, SUM(category_revenue) AS total_rev FROM category_stats GROUP BY year_number
),
category_ranked AS (
    SELECT *,
        RANK() OVER (PARTITION BY year_number ORDER BY category_revenue DESC) AS revenue_rank,
        RANK() OVER (PARTITION BY year_number ORDER BY ISNULL(avg_review, 5) DESC) AS review_rank,
        RANK() OVER (PARTITION BY year_number ORDER BY freight_pct DESC) AS freight_rank,
        ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY ISNULL(avg_review, 5)) AS review_rn_asc
    FROM category_stats
),
state_seller_stats AS (
    SELECT
        d.year_number, s.state,
        SUM(oi.total_item_value) AS state_revenue,
        COUNT(DISTINCT oi.seller_id) AS sellers_in_state
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Fact_Orders o ON oi.order_id = o.order_id
    INNER JOIN Gold.Dim_Date d ON o.purchase_date_key = d.date_key
    INNER JOIN Gold.Dim_Sellers s ON oi.seller_id = s.seller_id
    WHERE o.order_status NOT IN (''created'', ''approved'', ''canceled'', ''unavailable'') 
    GROUP BY d.year_number, s.state
),
state_ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY state_revenue DESC) AS revenue_rn
    FROM state_seller_stats
),
product_revenue AS (
    SELECT d.year_number, oi.product_id, SUM(oi.price) AS prod_rev
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Fact_Orders o ON oi.order_id = o.order_id 
    INNER JOIN Gold.Dim_Date d ON o.purchase_date_key = d.date_key
    WHERE o.order_status NOT IN (''created'', ''approved'', ''canceled'', ''unavailable'') 
    GROUP BY d.year_number, oi.product_id
),
product_ranked AS (
    SELECT *,
        SUM(prod_rev) OVER (PARTITION BY year_number) AS total_rev,
        SUM(prod_rev) OVER (PARTITION BY year_number ORDER BY prod_rev DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_rev,
        ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY prod_rev DESC) AS rn,
        COUNT(*) OVER (PARTITION BY year_number) AS total_products
    FROM product_revenue
),
pareto AS (
    SELECT year_number, COUNT(*) AS top20pct_products, ROUND(MAX(running_rev) / MAX(total_rev) * 100, 1) AS revenue_covered
    FROM product_ranked WHERE rn <= CAST(total_products * 0.2 AS INT) GROUP BY year_number
),
category_yoy AS (
    SELECT
        cur.year_number, cur.category_name_en, cur.category_revenue AS current_rev, prev.category_revenue AS prior_rev,
        ROUND((cur.category_revenue - prev.category_revenue) / NULLIF(prev.category_revenue, 0) * 100, 1) AS yoy_pct
    FROM category_stats cur
    LEFT JOIN category_stats prev ON cur.category_name_en = prev.category_name_en AND prev.year_number = cur.year_number - 1
),
top_yoy AS (
    SELECT * FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY yoy_pct DESC) as rnk 
        FROM category_yoy WHERE prior_rev > 50000 
    ) t WHERE rnk = 1
)
SELECT cr.year_number, ''Top Revenue Category'' AS kpi_name, cr.category_revenue AS kpi_value, ''#1 revenue-generating category'' AS kpi_meaning, ''SUM(price)'' AS sql_logic, ''Category Name'' AS context_name, cr.category_name_en AS context_value, ''Main revenue driver'' AS context_meaning FROM category_ranked cr WHERE cr.revenue_rank = 1
UNION ALL
SELECT ty.year_number, ''Fastest-Growing Category (YoY)'', ty.current_rev, ''Highest revenue growth'', ''YoY Formula'', ''Growth Rate'', CAST(ty.yoy_pct AS VARCHAR(20)) + ''%'', ty.category_name_en + '' trending upward'' FROM top_yoy ty
UNION ALL
SELECT cr.year_number, ''Highest Freight Burden'', cr.freight_pct, ''Logistics cost share'', ''SUM(freight) / SUM(total_value)'', ''Freight %'', CAST(cr.freight_pct AS VARCHAR(20)) + ''%'', cr.category_name_en + '' margin risk'' FROM category_ranked cr WHERE cr.freight_rank = 1
UNION ALL
SELECT cr.year_number, ''Lowest Customer Satisfaction'', cr.avg_review, ''Category with poor feedback'', ''AVG(review)'', ''Avg Score'', cr.category_name_en + '' | '' + CAST(ROUND(cr.avg_review, 2) AS VARCHAR(20)), ''Poor satisfaction risk'' FROM category_ranked cr WHERE cr.review_rn_asc = 1
UNION ALL
SELECT sr.year_number, ''Top Seller State (Revenue)'', sr.state_revenue, ''Highest seller output'', ''SUM(revenue)'', ''State + Sellers'', sr.state + '' | '' + CAST(sr.sellers_in_state AS VARCHAR(20)) + '' sellers'', ''Primary supply hub'' FROM state_ranked sr WHERE sr.revenue_rn = 1
UNION ALL
SELECT pa.year_number, ''Product Revenue Concentration'', pa.revenue_covered, ''% of revenue from top 20% products'', ''Pareto 80/20'', ''Top 20% Count'', CAST(pa.top20pct_products AS VARCHAR(20)) + '' products'', ''Heavy dependence on core products'' FROM pareto pa;');

    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold_Views', @Table_Name, 'Gold.Deploy_Dashboard_System', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, 0, 0, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 3. Marketing Funnel View (Added Order Filter to Revenue)
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.vw_marketing_dashboard_kpis'; SET @Load_Start = SYSDATETIME();
    EXEC('CREATE OR ALTER VIEW gold.vw_marketing_dashboard_kpis AS
WITH funnel_overall AS (
    SELECT
        d.year_number,
        COUNT(mql_id) AS total_mqls,
        SUM(CASE WHEN is_converted = 1 THEN 1 ELSE 0 END) AS total_converted,
        ROUND(CAST(SUM(CASE WHEN is_converted=1 THEN 1 ELSE 0 END) AS FLOAT) / NULLIF(COUNT(mql_id), 0) * 100, 2) AS overall_conversion_rate,
        ROUND(AVG(CASE WHEN is_converted = 1 THEN CAST(days_to_close AS FLOAT) ELSE NULL END), 1) AS avg_days_to_close
    FROM Gold.Fact_Marketing_Funnel f
    INNER JOIN Gold.Dim_Date d ON f.first_contact_date_key = d.date_key
    GROUP BY d.year_number
),
channel_stats AS (
    SELECT
        d.year_number, lead_origin,
        COUNT(mql_id) AS mqls,
        SUM(CASE WHEN is_converted = 1 THEN 1 ELSE 0 END) AS converted,
        ROUND(CAST(SUM(CASE WHEN is_converted=1 THEN 1 ELSE 0 END) AS FLOAT) / NULLIF(COUNT(mql_id), 0) * 100, 2) AS conv_rate,
        ROUND(AVG(CASE WHEN is_converted = 1 THEN CAST(days_to_close AS FLOAT) ELSE NULL END), 1) AS avg_close_days
    FROM Gold.Fact_Marketing_Funnel f
    INNER JOIN Gold.Dim_Date d ON f.first_contact_date_key = d.date_key
    GROUP BY d.year_number, lead_origin
),
channel_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY conv_rate DESC) AS conv_rn_desc,
        ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY avg_close_days) AS speed_rn_asc,
        ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY conv_rate) AS conv_rn_asc
    FROM channel_stats WHERE mqls >= 10
),
mktg_revenue AS (
    SELECT
        d.year_number, s.came_from_marketing,
        SUM(oi.total_item_value) AS total_revenue,
        COUNT(DISTINCT oi.seller_id) AS seller_count,
        SUM(oi.total_item_value) / NULLIF(COUNT(DISTINCT oi.seller_id), 0) AS revenue_per_seller
    FROM Gold.Fact_Order_Items oi
    INNER JOIN Gold.Fact_Orders o ON oi.order_id = o.order_id 
    INNER JOIN Gold.Dim_Sellers s ON oi.seller_id = s.seller_id
    INNER JOIN Gold.Dim_Date d ON o.purchase_date_key = d.date_key
    WHERE o.order_status NOT IN (''created'', ''approved'', ''canceled'', ''unavailable'') 
    GROUP BY d.year_number, s.came_from_marketing
),
sdr_stats AS (
    SELECT
        d.year_number, sdr_id,
        COUNT(mql_id) AS leads_handled,
        SUM(CASE WHEN is_converted = 1 THEN 1 ELSE 0 END) AS deals_closed,
        ROUND(CAST(SUM(CASE WHEN is_converted=1 THEN 1 ELSE 0 END) AS FLOAT) / NULLIF(COUNT(mql_id), 0) * 100, 2) AS conv_rate
    FROM Gold.Fact_Marketing_Funnel f
    INNER JOIN Gold.Dim_Date d ON f.first_contact_date_key = d.date_key
    WHERE sdr_id IS NOT NULL
    GROUP BY d.year_number, sdr_id
    HAVING COUNT(mql_id) >= 5
),
sdr_ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY conv_rate DESC) AS rank_asc FROM sdr_stats
)
SELECT f.year_number, ''Seller Acquisition Conversion Rate'' AS kpi_name, f.overall_conversion_rate AS kpi_value, ''MQLs to active sellers'' AS kpi_meaning, ''SUM/COUNT'' AS sql_calculation_logic, ''Total Pipeline'' AS context_name, CAST(f.total_mqls AS VARCHAR(20)) + '' MQLs'' AS context_value, ''Funnel health'' AS context_meaning FROM funnel_overall f
UNION ALL
SELECT cr.year_number, ''Best-Converting Acquisition Channel'', cr.conv_rate, ''Highest MQL-to-seller'', ''SUM/COUNT'', ''Channel + Volume'', cr.lead_origin + '' | '' + CAST(cr.mqls AS VARCHAR(20)) + '' leads'', ''Top channel performance'' FROM channel_ranked cr WHERE cr.conv_rn_desc = 1
UNION ALL
SELECT cr.year_number, ''Fastest-Closing Acquisition Channel'', cr.avg_close_days, ''Shortest time to active'', ''AVG(days)'', ''Channel + Speed'', cr.lead_origin + '' | Avg '' + CAST(cr.avg_close_days AS VARCHAR(20)) + '' days'', ''Sales cycle speed'' FROM channel_ranked cr WHERE cr.speed_rn_asc = 1
UNION ALL
SELECT mr_mktg.year_number, ''Marketing-Sourced Seller Revenue'', mr_mktg.total_revenue, ''Revenue from marketing'', ''SUM(revenue)'', ''vs Organic Sellers'', ''Mktg: R$'' + CAST(ROUND(mr_mktg.total_revenue, 0) AS VARCHAR(20)), ''Marketing ROI'' FROM mktg_revenue mr_mktg INNER JOIN mktg_revenue mr_organic ON mr_mktg.year_number = mr_organic.year_number WHERE mr_mktg.came_from_marketing = 1 AND mr_organic.came_from_marketing = 0
UNION ALL
SELECT f.year_number, ''Average Sales Cycle Length'', f.avg_days_to_close, ''First contact to activation'', ''AVG(days)'', ''Cycle Length'', CAST(f.avg_days_to_close AS VARCHAR(20)) + '' days'', ''SDR capacity indicator'' FROM funnel_overall f
UNION ALL
SELECT sr.year_number, ''Top SDR Conversion Rate'', sr.conv_rate, ''Highest SDR conversion'', ''SUM/COUNT'', ''SDR ID + Deals'', ''SDR: '' + sr.sdr_id + '' | '' + CAST(sr.deals_closed AS VARCHAR(20)) + '' deals'', ''Team playbook'' FROM sdr_ranked sr WHERE sr.rank_asc = 1;');

    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold_Views', @Table_Name, 'Gold.Deploy_Dashboard_System', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, 0, 0, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 4. Customer Behavior View (Fixed State Grouping & Delivered only)
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.vw_customer_dashboard_kpis'; SET @Load_Start = SYSDATETIME();
    EXEC('CREATE OR ALTER VIEW gold.vw_customer_dashboard_kpis AS
WITH customer_history AS (
    SELECT
        d.year_number, 
        o.customer_unique_id, 
        MAX(c.state) AS state, -- لحل مشكلة العميل اللي غير عنوانه
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(o.total_payment) AS yearly_spend,
        AVG(CAST(o.review_score AS FLOAT)) AS avg_review,
        SUM(CASE WHEN o.is_late_delivery = 1 THEN 1 ELSE 0 END) AS late_orders_received,
        SUM(CASE WHEN o.review_score >= 4 THEN 1 ELSE 0 END) AS promoter_orders,
        SUM(CASE WHEN o.review_score <= 2 THEN 1 ELSE 0 END) AS detractor_orders
    FROM Gold.Fact_Orders o
    INNER JOIN Gold.Dim_Customers c ON o.customer_unique_id = c.customer_unique_id
    INNER JOIN Gold.Dim_Date d ON o.purchase_date_key = d.date_key
    WHERE o.order_status = ''delivered'' 
    GROUP BY d.year_number, o.customer_unique_id
),
repeat_analysis AS (
    SELECT
        year_number,
        COUNT(*) AS total_customers,
        SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END) AS single_buyers, 
        SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END) AS repeat_buyers,
        SUM(yearly_spend) AS total_revenue,
        AVG(yearly_spend) AS avg_yearly_value
    FROM customer_history 
    GROUP BY year_number
),
state_kpis AS (
    SELECT
        year_number, state,
        COUNT(DISTINCT customer_unique_id) AS customer_count,
        SUM(yearly_spend) AS state_revenue,
        AVG(yearly_spend) AS avg_customer_value,
        SUM(late_orders_received) * 100.0 / NULLIF(SUM(order_count), 0) AS late_delivery_rate
    FROM customer_history 
    GROUP BY year_number, state
),
state_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY customer_count DESC) AS cust_rn,
        ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY avg_customer_value DESC) AS ltv_rn,
        ROW_NUMBER() OVER (PARTITION BY year_number ORDER BY late_delivery_rate DESC) AS late_rn
    FROM state_kpis WHERE customer_count >= 20
),
quartile_analysis AS (
    SELECT
        year_number, yearly_spend,
        NTILE(4) OVER (PARTITION BY year_number ORDER BY yearly_spend) AS spend_quartile
    FROM customer_history
),
quartile_summary AS (
    SELECT
        year_number, spend_quartile,
        COUNT(*) AS customers,
        SUM(yearly_spend) AS quartile_revenue,
        SUM(SUM(yearly_spend)) OVER (PARTITION BY year_number) AS total_rev
    FROM quartile_analysis GROUP BY year_number, spend_quartile
)
SELECT ra.year_number, ''Repeat Customer Rate'' AS kpi_name, ROUND(ra.repeat_buyers * 100.0 / NULLIF(ra.total_customers, 0), 2) AS kpi_value, ''% of customers with >1 order in year'' AS kpi_meaning, ''(Repeat Buyers / Total) * 100'' AS sql_calculation_logic, ''Comparison (1 vs >1)'' AS context_name, CAST(ra.repeat_buyers AS VARCHAR(20)) + '' Repeat vs '' + CAST(ra.single_buyers AS VARCHAR(20)) + '' Single'' AS context_value, ''Retention indicator'' AS context_meaning FROM repeat_analysis ra
UNION ALL
SELECT ra.year_number, ''Average Customer Value (Yearly)'', ROUND(ra.avg_yearly_value, 2), ''Average revenue per customer per year'', ''SUM/COUNT'', ''Value Insight'', ''Avg Value: R$'' + CAST(ROUND(ra.avg_yearly_value, 2) AS VARCHAR(20)), ''Yearly spend analysis'' FROM repeat_analysis ra
UNION ALL
SELECT sr.year_number, ''Largest Customer Market'', CAST(sr.customer_count AS FLOAT), ''Highest number of customers'', ''COUNT(customers)'', ''State'', sr.state + '' | '' + CAST(sr.customer_count AS VARCHAR(20)) + '' customers'', ''Market size'' FROM state_ranked sr WHERE sr.cust_rn = 1
UNION ALL
SELECT sr.year_number, ''Worst Customer Experience State'', ROUND(sr.late_delivery_rate, 1), ''Highest late delivery rate'', ''SUM(late)/COUNT(orders)'', ''State + Late Rate'', sr.state + '' | '' + CAST(ROUND(sr.late_delivery_rate, 1) AS VARCHAR(20)) + ''% late'', ''Logistics improvement needed'' FROM state_ranked sr WHERE sr.late_rn = 1
UNION ALL
SELECT qs.year_number, ''Top 25% Customer Contribution'', ROUND(qs.quartile_revenue * 100.0 / NULLIF(qs.total_rev, 0), 1), ''Revenue % from top 25%'', ''NTILE(4) Revenue'', ''Top Quartile'', CAST(qs.customers AS VARCHAR(20)) + '' customers'', ''VIP revenue impact'' FROM quartile_summary qs WHERE qs.spend_quartile = 4;');

    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold_Views', @Table_Name, 'Gold.Deploy_Dashboard_System', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, 0, 0, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- Batch Close
    -- ════════════════════════════════════════════════════════════════
    UPDATE [Audit].[ETL_Log]
    SET    Batch_End_Time      = SYSDATETIME(),
           Batch_Duration_Sec  = DATEDIFF(SECOND, @Batch_Start, SYSDATETIME())
    WHERE  Batch_Id = @Batch_Id; 

    PRINT '=================================================';
    PRINT '      All Gold Views Deployed Successfully';
    PRINT '=================================================';

    END TRY
    BEGIN CATCH
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