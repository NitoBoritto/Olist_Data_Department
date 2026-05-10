CREATE OR ALTER PROCEDURE Gold.Load_Gold 
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF; -- عشان رسايل الـ Null متبوظش الـ Log

    -- ── Batch-level variables ─────────────────────────────────────────
    DECLARE @Batch_Id          UNIQUEIDENTIFIER = NEWID();
    DECLARE @Batch_Start       DATETIME2        = SYSDATETIME();
    DECLARE @Table_Name        NVARCHAR(150);
    DECLARE @Load_Start        DATETIME2;
    DECLARE @Rows_Inserted     INT;
    DECLARE @Target_Count      INT;

    BEGIN TRY

    PRINT '=================================================';
    PRINT '== Gold Layer Load Started: ' + CONVERT(NVARCHAR, @Batch_Start, 120);
    PRINT '=================================================';

    -- ════════════════════════════════════════════════════════════════
    -- 0. CLEANUP (الترتيب العكسي للمسح لضمان الـ Foreign Keys)
    -- ════════════════════════════════════════════════════════════════
    PRINT '-- >> Cleaning up Fact tables...';
    DELETE FROM Gold.Fact_Order_Items;
    DELETE FROM Gold.Fact_Marketing_Funnel;
    DELETE FROM Gold.Fact_Orders;
    
    PRINT '-- >> Cleaning up Dimension tables...';
    DELETE FROM Gold.Dim_Products;
    DELETE FROM Gold.Dim_Customers;
    DELETE FROM Gold.Dim_Sellers;
    DELETE FROM Gold.Dim_Date;

    -- ════════════════════════════════════════════════════════════════
    -- 1. Dim_Date (توسيع النطاق لضمان تغطية كل التواريخ)
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.Dim_Date'; SET @Load_Start = SYSDATETIME();
    WITH Date_Range AS (
        SELECT CAST('2015-01-01' AS DATE) AS full_date -- بدأنا من 2015 للأمان
        UNION ALL
        SELECT DATEADD(day, 1, full_date) FROM Date_Range WHERE full_date < '2020-12-31'
    )
    INSERT INTO Gold.Dim_Date (date_key, full_date, year_number, quarter_number, month_number, month_name, day_name, is_weekend)
    SELECT CAST(CONVERT(VARCHAR(8), full_date, 112) AS INT), full_date, YEAR(full_date), DATEPART(QUARTER, full_date), MONTH(full_date), DATENAME(MONTH, full_date), DATENAME(WEEKDAY, full_date), CASE WHEN DATENAME(WEEKDAY, full_date) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END
    FROM Date_Range OPTION (MAXRECURSION 3000);
    SET @Rows_Inserted = @@ROWCOUNT; SELECT @Target_Count = COUNT(*) FROM Gold.Dim_Date;
    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold', @Table_Name, 'Gold.Load_Gold', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, @Rows_Inserted, @Target_Count, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 2. Dim_Products[cite: 1, 2]
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.Dim_Products'; SET @Load_Start = SYSDATETIME();
    INSERT INTO Gold.Dim_Products (product_id, category_name_pt, category_name_en, name_length, description_length, photo_count, weight_g, length_cm, height_cm, width_cm, volume_cm3)
    SELECT P.product_id, P.product_category_name, C.product_category_name_english, P.product_name_length, P.product_description_length, P.product_photos_qty, P.product_weight_g, P.product_length_cm, P.product_height_cm, P.product_width_cm, (CAST(P.product_length_cm AS INT) * P.product_height_cm * P.product_width_cm)
    FROM Silver.Erp_products AS P 
    LEFT JOIN Silver.Erp_product_category_name_translation AS C ON P.product_category_name = C.product_category_name;
    SET @Rows_Inserted = @@ROWCOUNT; SELECT @Target_Count = COUNT(*) FROM Gold.Dim_Products;
    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold', @Table_Name, 'Gold.Load_Gold', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, @Rows_Inserted, @Target_Count, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 3. Dim_Customers[cite: 1, 2]
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.Dim_Customers'; SET @Load_Start = SYSDATETIME();
    WITH Deduplicated_Customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY customer_id) AS rn FROM Silver.Crm_customers
    ),
    Geo_Safe AS (
        SELECT geolocation_zip_code_prefix, geolocation_state, AVG(geolocation_lat) AS lat, AVG(geolocation_lng) AS lng
        FROM Silver.Erp_geolocation GROUP BY geolocation_zip_code_prefix, geolocation_state
    )
    INSERT INTO Gold.Dim_Customers (customer_unique_id, zip_code, city, state, latitude, longitude)
    SELECT dc.customer_unique_id, dc.customer_zip_code_prefix, dc.customer_city, dc.customer_state, g.lat, g.lng
    FROM Deduplicated_Customers dc 
    LEFT JOIN Geo_Safe g ON dc.customer_zip_code_prefix = g.geolocation_zip_code_prefix AND dc.customer_state = g.geolocation_state 
    WHERE dc.rn = 1;
    SET @Rows_Inserted = @@ROWCOUNT; SELECT @Target_Count = COUNT(*) FROM Gold.Dim_Customers;
    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold', @Table_Name, 'Gold.Load_Gold', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, @Rows_Inserted, @Target_Count, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 4. Dim_Sellers[cite: 1, 2]
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.Dim_Sellers'; SET @Load_Start = SYSDATETIME();
    WITH Dedup_Deals AS (
        SELECT seller_id, business_segment, business_type, lead_type, lead_behaviour_profile, declared_product_catalog_size, declared_monthly_revenue,
               ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY won_date DESC) AS row_flag
        FROM Silver.Crm_closed_deals
    )
    INSERT INTO Gold.Dim_Sellers (seller_id, zip_code, city, state, latitude, longitude, business_segment, business_type, lead_type, behaviour_profile, catalog_size, declared_monthly_revenue, came_from_marketing)
    SELECT s.seller_id, s.seller_zip_code_prefix, s.seller_city, s.seller_state, g.geolocation_lat, g.geolocation_lng, cd.business_segment, cd.business_type, cd.lead_type, cd.lead_behaviour_profile, cd.declared_product_catalog_size, cd.declared_monthly_revenue,
           CASE WHEN cd.seller_id IS NOT NULL THEN 1 ELSE 0 END
    FROM Silver.Erp_sellers s
    LEFT JOIN Dedup_Deals cd ON s.seller_id = cd.seller_id AND cd.row_flag = 1
    LEFT JOIN Silver.Erp_geolocation g ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix AND s.seller_state = g.geolocation_state;
    SET @Rows_Inserted = @@ROWCOUNT; SELECT @Target_Count = COUNT(*) FROM Gold.Dim_Sellers;
    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold', @Table_Name, 'Gold.Load_Gold', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, @Rows_Inserted, @Target_Count, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 5. Fact_Orders[cite: 1, 2]
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.Fact_Orders'; SET @Load_Start = SYSDATETIME();
    WITH Latest_Reviews AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_creation_date DESC) AS rn FROM Silver.Crm_order_reviews
    ),
    Payments_Agg AS (
        SELECT order_id, SUM(payment_value) AS total_payment, MAX(CASE WHEN payment_rank = 1 THEN payment_type END) AS primary_payment_type
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_value DESC) AS payment_rank FROM Silver.Erp_order_payments) p GROUP BY order_id
    )
    INSERT INTO Gold.Fact_Orders (order_id, customer_unique_id, purchase_date_key, order_status, total_payment, primary_payment_type, review_score, review_text, delivery_days_actual, is_late_delivery, is_invalid_payment)
    SELECT o.order_id, c.customer_unique_id, CAST(CONVERT(VARCHAR(8), o.order_purchase_timestamp, 112) AS INT), o.order_status, pay.total_payment, pay.primary_payment_type, r.review_score, r.review_comment_message,
           DATEDIFF(day, o.order_purchase_timestamp, o.order_delivered_customer_date),
           Cast(CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END AS Bit),
           Cast(CASE  WHEN pay.total_payment <= 0 THEN 1 ELSE 0 END As Bit)
    FROM Silver.Erp_orders o
    LEFT JOIN Silver.Crm_customers c ON o.customer_id = c.customer_id
    INNER JOIN Gold.Dim_Customers dc ON c.customer_unique_id = dc.customer_unique_id -- لضمان وجود العميل
    LEFT JOIN Latest_Reviews r ON o.order_id = r.order_id AND r.rn = 1
    LEFT JOIN Payments_Agg pay ON o.order_id = pay.order_id;
    SET @Rows_Inserted = @@ROWCOUNT; SELECT @Target_Count = COUNT(*) FROM Gold.Fact_Orders;
    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold', @Table_Name, 'Gold.Load_Gold', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, @Rows_Inserted, @Target_Count, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 6. Fact_Order_Items[cite: 1, 2]
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.Fact_Order_Items'; SET @Load_Start = SYSDATETIME();
    INSERT INTO Gold.Fact_Order_Items (order_item_key, order_id, product_id, seller_id, purchase_date_key, order_purchase_timestamp, order_delivered_customer_date, price, freight_value, total_item_value)
    SELECT oi.order_item_key, oi.order_id, p.product_id, s.seller_id, CAST(CONVERT(VARCHAR(8), o.order_purchase_timestamp, 112) AS INT), o.order_purchase_timestamp, o.order_delivered_customer_date, oi.price, oi.freight_value, (oi.price + oi.freight_value)
    FROM Silver.Erp_order_items oi
    INNER JOIN Silver.Erp_orders o ON oi.order_id = o.order_id
    INNER JOIN Gold.Dim_Products p ON oi.product_id = p.product_id -- فلترة المنتجات غير الموجودة
    INNER JOIN Gold.Dim_Sellers s ON oi.seller_id = s.seller_id; -- فلترة البائعين غير الموجودين
    SET @Rows_Inserted = @@ROWCOUNT; SELECT @Target_Count = COUNT(*) FROM Gold.Fact_Order_Items;
    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold', @Table_Name, 'Gold.Load_Gold', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, @Rows_Inserted, @Target_Count, 'SUCCESS');

    -- ════════════════════════════════════════════════════════════════
    -- 7. Fact_Marketing_Funnel (الحل السحري لمشكلة الـ FK)[cite: 1, 2]
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name = 'Gold.Fact_Marketing_Funnel'; SET @Load_Start = SYSDATETIME();
    INSERT INTO Gold.Fact_Marketing_Funnel (mql_id, seller_id, first_contact_date_key, won_date_key, lead_origin, landing_page_id, sdr_id, sr_id, is_converted, days_to_close)
    SELECT m.mql_id, 
           s.seller_id, -- سحب الـ ID من جدول الجولد لضمان الـ FK
           CAST(CONVERT(VARCHAR(8), m.first_contact_date, 112) AS INT), 
           CAST(CONVERT(VARCHAR(8), c.won_date, 112) AS INT), 
           m.origin, m.landing_page_id, c.sdr_id, c.sr_id,
           CASE WHEN c.seller_id IS NOT NULL THEN 1 ELSE 0 END, DATEDIFF(day, m.first_contact_date, c.won_date)
    FROM Silver.Crm_marketing_qualified_leads m
    LEFT JOIN Silver.Crm_closed_deals c ON m.mql_id = c.mql_id
    LEFT JOIN Gold.Dim_Sellers s ON c.seller_id = s.seller_id; -- لو مش موجود هينزل NULL وميشتمش الـ FK[cite: 2]
    
    SET @Rows_Inserted = @@ROWCOUNT; SELECT @Target_Count = COUNT(*) FROM Gold.Fact_Marketing_Funnel;
    INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Gold', @Table_Name, 'Gold.Load_Gold', @Batch_Start, @Load_Start, SYSDATETIME(), DATEDIFF(SECOND, @Load_Start, SYSDATETIME()), 0, @Rows_Inserted, @Target_Count, 'SUCCESS');

    UPDATE [Audit].[ETL_Log] SET Batch_End_Time = SYSDATETIME(), Batch_Duration_Sec = DATEDIFF(SECOND, @Batch_Start, SYSDATETIME()) WHERE Batch_Id = @Batch_Id;
    PRINT '=================================================';
    PRINT '      Total Gold Layer Is Completed Successfully';
    PRINT '=================================================';

    END TRY
    BEGIN CATCH
        UPDATE [Audit].[ETL_Log] SET Batch_End_Time = SYSDATETIME(), Batch_Duration_Sec = DATEDIFF(SECOND, @Batch_Start, SYSDATETIME()) WHERE Batch_Id = @Batch_Id AND Batch_End_Time IS NULL;
        INSERT INTO [Audit].[ETL_Log] (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Status, Error_Message, Error_Number, Error_State)
        VALUES (@Batch_Id, 'Gold', @Table_Name, 'Gold.Load_Gold', 'FAILED', ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_STATE());
        THROW;
    END CATCH
END
GO