SELECT 
    c.customer_unique_id,

    -- RECENCY
    DATEDIFF(
        DAY, 
        CAST(CAST(MAX(o.purchase_date_key) AS VARCHAR(8)) AS DATE), 
        (SELECT CAST(CAST(MAX(purchase_date_key) AS VARCHAR(8)) AS DATE) 
         FROM Gold.Fact_Orders)
    ) AS recency,

    -- FREQUENCY
    COUNT(DISTINCT o.order_id) AS frequency,

    -- MONETARY: sourced from Fact_Order_Items, not Fact_Orders
    SUM(oi.price + oi.freight_value) AS monetary,

    -- BEHAVIORAL
    AVG(o.delivery_days_actual) AS avg_delivery_time,

    -- DIVERSITY
    COUNT(DISTINCT p.category_name_en) AS category_diversity

FROM Gold.Dim_Customers c
JOIN Gold.Fact_Orders o       ON c.customer_unique_id = o.customer_unique_id
JOIN Gold.Fact_Order_Items oi ON o.order_id = oi.order_id
JOIN Gold.Dim_Products p      ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_unique_id;