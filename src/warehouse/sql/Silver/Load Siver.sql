CREATE OR ALTER PROCEDURE Silver.Load_Silver 
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Batch-level variables ─────────────────────────────────────────
    DECLARE @Batch_Id          UNIQUEIDENTIFIER = NEWID();
    DECLARE @Batch_Start       DATETIME2        = SYSDATETIME();
    DECLARE @Batch_End         DATETIME2;
    DECLARE @Batch_Duration    INT;

    -- ── Table-level variables ─────────────────────────────────────────
    DECLARE @Table_Name        NVARCHAR(150);
    DECLARE @Load_Start        DATETIME2;
    DECLARE @Load_End          DATETIME2;
    DECLARE @Load_Duration     INT;
    DECLARE @Source_Count      INT;
    DECLARE @Rows_Inserted     INT;
    DECLARE @Target_Count      INT;

    BEGIN TRY

    PRINT '=================================================';
    PRINT '== Silver Layer Load Started: ' + CONVERT(NVARCHAR, @Batch_Start, 120);
    PRINT '=================================================';

    PRINT '============================ Transforming CRM Tables ============================';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Crm_order_reviews
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Crm_order_reviews';
SET @Load_Start  = SYSDATETIME();

-- Get Source Count for Audit
SELECT @Source_Count = COUNT(*) FROM Bronze.Crm_order_reviews;

PRINT '-- >> Truncating & Inserting: ' + @Table_Name;

TRUNCATE TABLE Silver.Crm_order_reviews;

WITH DeduplicatedReviews AS (
    SELECT
        *,
        ROW_NUMBER() OVER(PARTITION BY review_id ORDER BY review_creation_date DESC) AS Flag_review_id
    FROM Bronze.Crm_order_reviews
)
INSERT INTO Silver.Crm_order_reviews (
    review_id, 
    order_id, 
    review_score, 
    review_comment_title, 
    review_comment_message, 
    review_creation_date, 
    review_answer_timestamp, 
    load_date_timestamp
)
SELECT
    d.review_id,
    d.order_id,
    TRY_CAST(d.review_score AS INT) AS review_score,

    -- 1. Clean Title: Pipeline Result -> Whitespace Collapse -> Lower -> Trim -> Nullif
    NULLIF(TRIM(LOWER(
        REPLACE(REPLACE(REPLACE(FinalStep.CleanTitle, N' ', N'<>'), N'><', N''), N'<>', N' ')
    )), N'') AS review_comment_title,

    -- 2. Clean Message: Pipeline Result -> Whitespace Collapse -> Lower -> Trim -> Nullif
    NULLIF(TRIM(LOWER(
        REPLACE(REPLACE(REPLACE(FinalStep.CleanMsg, N' ', N'<>'), N'><', N''), N'<>', N' ')
    )), N'') AS review_comment_message,

    TRY_CONVERT(DATETIME2, d.review_creation_date)    AS review_creation_date,
    TRY_CONVERT(DATETIME2, d.review_answer_timestamp) AS review_answer_timestamp,
    SYSDATETIME() AS load_date_timestamp

FROM DeduplicatedReviews d

-- STEP 0: Binary casting and NBSP (hidden web space) correction
CROSS APPLY (
    SELECT 
        BaseTitle = REPLACE(CAST(CAST(ISNULL(d.review_comment_title, '') AS VARBINARY(MAX)) AS NVARCHAR(MAX)), CHAR(160), ' '),
        BaseMsg   = REPLACE(CAST(CAST(ISNULL(d.review_comment_message, '') AS VARBINARY(MAX)) AS NVARCHAR(MAX)), CHAR(160), ' ')
) AS Step0

-- STEP 1: Fix Triple-Encoded Lowercase Vowels + 'ñ' (├â┬ sequences)
CROSS APPLY (
    SELECT 
        T1_Title = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Step0.BaseTitle, 
            N'├â┬ú', N'ã'), N'├â┬⌐', N'é'), N'├â┬í', N'á'), N'├â┬│', N'ó'), N'├â┬º', N'ç'), N'├â┬▒', N'ñ'),
            N'├â┬¬', N'ê'), N'├â┬¡', N'í'), N'├â┬║', N'ú'), N'├â┬╡', N'õ'), N'├â┬á', N'à'), N'├â┬ó', N'ô'),
        T1_Msg   = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Step0.BaseMsg, 
            N'├â┬ú', N'ã'), N'├â┬⌐', N'é'), N'├â┬í', N'á'), N'├â┬│', N'ó'), N'├â┬º', N'ç'), N'├â┬▒', N'ñ'),
            N'├â┬¬', N'ê'), N'├â┬¡', N'í'), N'├â┬║', N'ú'), N'├â┬╡', N'õ'), N'├â┬á', N'à'), N'├â┬ó', N'ô')
) AS Step1

-- STEP 2: Fix Uppercase Encoding and remaining symbols
CROSS APPLY (
    SELECT 
        T2_Title = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Step1.T1_Title, 
            N'├â╞Æ', N'Ã'), N'├âΓÇ£', N'Ó'), N'├âΓÇÖ', N'Ó'), N'├âΓÇ░', N'É'), N'├âΓÇí', N'Ç'), N'├âΓÇ¥', N'Ô'), N'├âΓÇÜ', N'Ã'),
        T2_Msg   = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Step1.T1_Msg, 
            N'├â╞Æ', N'Ã'), N'├âΓÇ£', N'Ó'), N'├âΓÇÖ', N'Ó'), N'├âΓÇ░', N'É'), N'├âΓÇí', N'Ç'), N'├âΓÇ¥', N'Ô'), N'├âΓÇÜ', N'Ã')
) AS Step2

-- STEP 3: Remove Punctuation
CROSS APPLY (
    SELECT 
        T3_Title = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Step2.T2_Title, 
            N'.',N''),N',',N''),N'!',N''),N'?',N''),N';',N''),N':',N''),N'-',N' '),N'"',N''),N'(',N''),N')',N''),
        T3_Msg   = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Step2.T2_Msg, 
            N'.',N''),N',',N''),N'!',N''),N'?',N''),N';',N''),N':',N''),N'-',N' '),N'"',N''),N'(',N''),N')',N'')
) AS Step3

-- STEP 4: Target Emoji Artifact Sequences (├░┼╕ patterns)
CROSS APPLY (
    SELECT 
        T4_Title = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Step3.T3_Title, 
            N'├░┼╕', N''), N'╦£', N''), N'γç', N''), N'┬å', N''), N'┬ì', N''), N'┬╝', N''), N'┬╜', N''), N'┬╗', N''),
        T4_Msg   = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Step3.T3_Msg, 
            N'├░┼╕', N''), N'╦£', N''), N'γç', N''), N'┬å', N''), N'┬ì', N''), N'┬╝', N''), N'┬╜', N''), N'┬╗', N'')
) AS Step4

-- STEP 5: Final strip of smart quotes and hex artifacts
CROSS APPLY (
    SELECT 
        CleanTitle = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(T4_Title, 
            NCHAR(0x2018),N''), NCHAR(0x2019),N''), NCHAR(0x201C),N''), NCHAR(0x201D),N''), NCHAR(0x00F0),N''), NCHAR(0x00FF),N''), NCHAR(0x02DC),N''),
        CleanMsg   = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(T4_Msg, 
            NCHAR(0x2018),N''), NCHAR(0x2019),N''), NCHAR(0x201C),N''), NCHAR(0x201D),N''), NCHAR(0x00F0),N''), NCHAR(0x00FF),N''), NCHAR(0x02DC),N'')
) AS FinalStep

WHERE d.Flag_review_id = 1;

-- Post-Load Audit Log
SET @Rows_Inserted = @@ROWCOUNT;
SET @Target_Count = @Rows_Inserted;
SET @Load_End = SYSDATETIME();
SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

INSERT INTO Audit.ETL_Log (
    Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, 
    Load_Start_Time, Load_End_Time, Load_Duration_Sec, 
    Source_Row_Count, Rows_Inserted, Target_Row_Count, Status
)
VALUES (
    @Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, 
    @Load_Start, @Load_End, @Load_Duration, 
    @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS'
);

PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';
    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Crm_customers
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Crm_customers';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Crm_customers_dataset;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Crm_customers;

    INSERT INTO Silver.Crm_customers (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, load_date_timestamp)
    SELECT
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        REPLACE(customer_city,'-',' ') customer_city,
        UPPER(customer_state) customer_state,
        SYSDATETIME() AS load_date_timestamp
    FROM Bronze.Crm_customers_dataset;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Crm_closed_deals
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Crm_closed_deals';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Crm_closed_deals;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Crm_closed_deals;

    INSERT INTO Silver.Crm_closed_deals (mql_id, seller_id, sdr_id, sr_id, won_date, business_segment, lead_type, lead_behaviour_profile, has_company, has_gtin, average_stock, business_type, declared_product_catalog_size, declared_monthly_revenue, load_date_timestamp)
    SELECT
        mql_id,
        seller_id,
        sdr_id,
        sr_id,
        TRY_CONVERT(DATETIME, won_date) won_date,
        REPLACE(business_segment,'_',' ') business_segment,
        REPLACE(lead_type,'_',' ') lead_type,
        lead_behaviour_profile,
        TRY_CAST(has_company AS bit) has_company,
        TRY_CAST(has_gtin As bit) has_gtin,
        CASE    
            WHEN average_stock ='5-Jan' THEN '1-5'
            WHEN average_stock ='20-May' THEN '5-20'
            ELSE average_stock
        END AS average_stock,
        business_type,
        TRY_CAST(declared_product_catalog_size AS INT) declared_product_catalog_size,
        TRY_CAST(declared_monthly_revenue AS INT) declared_monthly_revenue,
        SYSDATETIME() AS load_date_timestamp
    FROM Bronze.Crm_closed_deals;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Crm_marketing_qualified_leads
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Crm_marketing_qualified_leads';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Crm_marketing_qualified_leads;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Crm_marketing_qualified_leads;

    INSERT INTO Silver.Crm_marketing_qualified_leads (mql_id, first_contact_date, landing_page_id, origin, load_date_timestamp)
    SELECT
        mql_id,
        TRY_CONVERT(DATETIME, first_contact_date) first_contact_date,
        landing_page_id,
        REPLACE(origin,'_',' ') origin,
        SYSDATETIME() AS load_date_timestamp
    FROM Bronze.Crm_marketing_qualified_leads;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    PRINT '============================ Transforming ERP Tables ============================';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Erp_geolocation
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Erp_geolocation';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Erp_geolocation;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Erp_geolocation;

    WITH DeduplicatedGeo AS (
        SELECT 
            geolocation_zip_code_prefix,
            AVG(TRY_CAST(geolocation_lat AS NUMERIC(18,10))) AS geolocation_lat,
            AVG(TRY_CAST(geolocation_lng AS NUMERIC(18,10))) AS geolocation_lng,
            MIN(LOWER(TRIM(geolocation_city))) AS raw_city, -- Pick one representative city per zip
            UPPER(geolocation_state) AS state_code
        FROM Bronze.Erp_geolocation
        GROUP BY geolocation_zip_code_prefix, UPPER(geolocation_state)
    ),
    CleaningPipeline AS (
        SELECT 
            g.*,
            Step3_Spaces.CleanedText AS processed_city
        FROM DeduplicatedGeo g
        CROSS APPLY (
            SELECT MojibakeFixed = 
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    g.raw_city,
                'Ã¡', 'á'), 'Ã©', 'é'), 'Ã­', 'í'), 'Ã³', 'ó'), 'Ãº', 'ú'), 'Ã£', 'ã'), 'Ãµ', 'õ'), 'Ã§', 'ç'), 'Ãª', 'ê'), 'Ã¢', 'â'), 
                'Ã´', 'ô'), 'Ã¼', 'ü'), 'Âº', 'º'),
                '%26apos%3b', '''') 
        ) AS Step1_Encoding
        CROSS APPLY (
            SELECT AccentNormalized =
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    Step1_Encoding.MojibakeFixed,
                'á', 'a'), 'à', 'a'), 'ã', 'a'), 'â', 'a'),
                'é', 'e'), 'ê', 'e'),
                'í', 'i'),
                'ó', 'o'), 'ô', 'o'), 'õ', 'o')
        ) AS Step1B_Normalize
        CROSS APPLY (
            SELECT PunctFixed = 
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    Step1B_Normalize.AccentNormalized,
                ',', ''), '_', ' '), '*', ''), '(', ''), ')', ''), ' - distrito', ''), 
                'ð', ''), 'ÿ', ''), '˜', ''), ' ', ''), '¤', ''), '—', ''), ' ', '') 
        ) AS Step2_PunctEmoji
        CROSS APPLY (
            SELECT CleanedText = 
                LTRIM(RTRIM(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        Step2_PunctEmoji.PunctFixed, 
                    ''' ', ''''),
                    '  ', ' '), '  ', ' '), '  ', ' '), '  ', ' ') 
                ))
        ) AS Step3_Spaces
    ),
    FinalLogic AS (
        SELECT 
            geolocation_zip_code_prefix,
            geolocation_lat,
            geolocation_lng,
            state_code,
            CASE 
                WHEN processed_city IN ('', 'unknown', 'cidade', 'geolocation_city') THEN NULL
                WHEN processed_city IN ('sp', 'rj', 'mg', 'es', 'ba', 'pr', 'sc', 'rs') THEN NULL
                WHEN processed_city LIKE '% ' + state_code AND LEN(processed_city) - LEN(state_code) >= 3 
                     THEN LTRIM(RTRIM(LEFT(processed_city, LEN(processed_city) - (LEN(state_code) + 1))))
                WHEN processed_city LIKE '...%' THEN REPLACE(processed_city, '...', '')
                ELSE processed_city 
            END AS geolocation_city_final
        FROM CleaningPipeline
    )
    INSERT INTO Silver.Erp_geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state, load_date_timestamp)
    SELECT 
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city_final AS geolocation_city,
        state_code AS geolocation_state,
        SYSDATETIME() AS load_date_timestamp
    FROM FinalLogic;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Erp_order_items
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Erp_order_items';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Erp_order_items;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Erp_order_items;

    INSERT INTO Silver.Erp_order_items (order_id, order_item_number, order_item_key, product_id, seller_id, shipping_limit_date, price, freight_value, load_date_timestamp)
    SELECT
        order_id,
        TRY_CAST(order_item_id AS INT) order_item_number,
        CAST(ROW_NUMBER() OVER(ORDER BY order_id, order_item_id) AS INT) order_item_key,
        product_id,
        seller_id,
        TRY_CONVERT(DATETIME, shipping_limit_date) shipping_limit_date,
        TRY_CAST(price AS DECIMAL(12,2)) price,
        TRY_CAST(freight_value AS DECIMAL(12,2)) freight_value,
        SYSDATETIME() AS load_date_timestamp
    FROM Bronze.Erp_order_items;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Erp_order_payments
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Erp_order_payments';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Erp_order_payments;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Erp_order_payments;

    INSERT INTO Silver.Erp_order_payments (order_id, payment_sequential, payment_type, payment_installments, payment_value, load_date_timestamp)
    SELECT
        order_id,
        TRY_CAST(payment_sequential AS INT) payment_sequential,
        REPLACE(payment_type,'_',' ') payment_type,
        TRY_CAST(payment_installments AS INT) payment_installments,
        TRY_CAST(payment_value AS DECIMAL(12,2)) payment_value,
        SYSDATETIME() AS load_date_timestamp
    FROM Bronze.Erp_order_payments;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Erp_orders
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Erp_orders';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Erp_orders;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Erp_orders;

    INSERT INTO Silver.Erp_orders (order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date, load_date_timestamp)
    SELECT
        order_id,
        customer_id,
        CASE 
            WHEN order_status = 'unavailable' THEN 'out of stock' 
            ELSE order_status 
        END AS order_status,
        TRY_CONVERT(DATETIME, order_purchase_timestamp) order_purchase_timestamp,
        TRY_CONVERT(DATETIME, order_approved_at) order_approved_at,
        TRY_CONVERT(DATETIME, order_delivered_carrier_date) order_delivered_carrier_date,
        TRY_CONVERT(DATETIME, order_delivered_customer_date) order_delivered_customer_date,
        TRY_CONVERT(DATETIME, order_estimated_delivery_date) order_estimated_delivery_date,
        SYSDATETIME() AS load_date_timestamp
    FROM Bronze.Erp_orders;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Erp_product_category_name_translation
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Erp_product_category_name_translation';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Erp_product_category_name_translation;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Erp_product_category_name_translation;

    INSERT INTO Silver.Erp_product_category_name_translation (product_category_name, product_category_name_english, load_date_timestamp)
    SELECT
        REPLACE(product_category_name,'_',' ') product_category_name,
        REPLACE(product_category_name_english,'_',' ') product_category_name_english,
        SYSDATETIME() AS load_date_timestamp
    FROM Bronze.Erp_product_category_name_translation;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Erp_products
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Erp_products';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Erp_products;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Erp_products;

    INSERT INTO Silver.Erp_products (product_id, product_category_name, product_name_length, product_description_length, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm, load_date_timestamp)
    SELECT
        product_id,
        REPLACE(product_category_name,'_',' ') product_category_name,
        TRY_CAST(product_name_length AS INT) product_name_length,
        TRY_CAST(product_description_length AS INT) product_description_length,
        TRY_CAST(product_photos_qty AS INT) product_photos_qty,
        TRY_CAST(product_weight_g AS INT) product_weight_g,
        TRY_CAST(product_length_cm AS INT) product_length_cm,
        TRY_CAST(product_height_cm AS INT) product_height_cm,
        TRY_CAST(product_width_cm AS INT) product_width_cm,
        SYSDATETIME() AS load_date_timestamp
    FROM Bronze.Erp_products;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Silver.Erp_sellers
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Silver.Erp_sellers';
    SET @Load_Start  = SYSDATETIME();
    
    SELECT @Source_Count = COUNT(*) FROM Bronze.Erp_sellers;
    
    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Silver.Erp_sellers;

    WITH RawSellers AS (
        SELECT 
            seller_id,
            seller_zip_code_prefix,
            LOWER(TRIM(seller_city)) AS raw_city,
            UPPER(seller_state) AS seller_state
        FROM Bronze.Erp_sellers
    ),
    CleaningPipeline AS (
        SELECT 
            r.*,
            Step5_Deduplicate.FinalText AS city_intermediate
        FROM RawSellers r
        CROSS APPLY (
            SELECT MojibakeFixed = 
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    r.raw_city,
                'Ã¡', 'á'), 'Ã©', 'é'), 'Ã­', 'í'), 'Ã³', 'ó'), 'Ãº', 'ú'), 'Ã£', 'ã'), 'Ãµ', 'õ'), 'Ã§', 'ç'), 'Ãª', 'ê'), 'Ã¢', 'â'), 
                'Ã´', 'ô'), 'Ã¼', 'ü'), 'Âº', 'º'),
                '%26apos%3b', '''')
        ) AS Step1_Encoding
        CROSS APPLY (
            SELECT CleanSuffix = 
                LTRIM(RTRIM(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    Step1_Encoding.MojibakeFixed,
                '/sp', ''), '/ sp', ''), '- sp', ''), ' sp', ''), 
                '/mg', ''), '/ mg', ''), ' minas gerais', ''),
                '/pr', ''), '/ pr', ''), '-pr', '')
                ))
        ) AS Step2_Suffix
        CROSS APPLY (
            SELECT CleanPunct = 
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    Step2_Suffix.CleanSuffix,
                '.', ''), ',', ''), '_', ' '), '/', ' '), '\', ' '), '*', '')
        ) AS Step3_Punct
        CROSS APPLY (
            SELECT CleanSpaces = 
                LTRIM(RTRIM(
                    REPLACE(REPLACE(REPLACE(Step3_Punct.CleanPunct, '  ', ' '), '  ', ' '), '  ', ' ')
                ))
        ) AS Step4_Spaces
        CROSS APPLY (
            SELECT FinalText = 
                CASE 
                    WHEN CHARINDEX(' ', Step4_Spaces.CleanSpaces) > 0 
                         AND LEFT(Step4_Spaces.CleanSpaces, CHARINDEX(' ', Step4_Spaces.CleanSpaces) - 1) = 
                             SUBSTRING(Step4_Spaces.CleanSpaces, CHARINDEX(' ', Step4_Spaces.CleanSpaces) + 1, LEN(Step4_Spaces.CleanSpaces))
                    THEN LEFT(Step4_Spaces.CleanSpaces, CHARINDEX(' ', Step4_Spaces.CleanSpaces) - 1)
                    ELSE Step4_Spaces.CleanSpaces
                END
        ) AS Step5_Deduplicate
    ),
    StandardizedSellers AS (
        SELECT 
            seller_id,
            seller_zip_code_prefix,
            seller_state,
            CASE 
                WHEN city_intermediate LIKE '%@%' OR city_intermediate LIKE '%[0-9]%' OR LEN(city_intermediate) < 2 THEN NULL
                WHEN city_intermediate IN ('sao paulo', 'sao pauo', 'sao paluo', 'sao pauol') THEN 'sao paulo'
                WHEN city_intermediate IN ('sao bernardo do campo', 'sao bernardo do capo', 'sbc', 'ao bernardo do campo') THEN 'sao bernardo do campo'
                WHEN city_intermediate IN ('ribeirao preto', 'riberao preto', 'riberao pretp', 'robeirao preto') THEN 'ribeirao preto'
                WHEN city_intermediate IN ('sao jose do rio pardo', 'scao jose do rio pardo') THEN 'sao jose do rio pardo'
                WHEN city_intermediate IN ('sao jose do rio preto', 's jose do rio preto', 'sao jose do rio pret') THEN 'sao jose do rio preto'
                WHEN city_intermediate IN ('florianopolis', 'floranopolis') THEN 'florianopolis'
                WHEN city_intermediate LIKE 'santa barbara d%oeste' THEN 'santa barbara d''oeste'
                ELSE city_intermediate 
            END AS seller_city_clean
        FROM CleaningPipeline
    )
    INSERT INTO Silver.Erp_sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state, load_date_timestamp)
    SELECT 
        seller_id,
        seller_zip_code_prefix,
        seller_city_clean AS seller_city,
        seller_state,
        SYSDATETIME() AS load_date_timestamp
    FROM StandardizedSellers;

    SET @Rows_Inserted = @@ROWCOUNT;
    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, @Source_Count, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] ' + @Table_Name + ' -> ' + CAST(@Rows_Inserted AS NVARCHAR) + ' rows inserted.';

    -- ── Batch close ──────────────────────────────────────────────────
    SET @Batch_End      = SYSDATETIME();
    SET @Batch_Duration = DATEDIFF(SECOND, @Batch_Start, @Batch_End);

    -- Back-fill batch end time on all rows written by this batch
    UPDATE Audit.ETL_Log
    SET Batch_End_Time      = @Batch_End,
        Batch_Duration_Sec  = @Batch_Duration
    WHERE Batch_Id = @Batch_Id;

    PRINT '=================================================';
    PRINT '      Total Silver Layer Is Completed';
    PRINT '  ->> Total Load Duration: ' + CAST(@Batch_Duration AS NVARCHAR) + ' Seconds';
    PRINT '=================================================';

    END TRY
    BEGIN CATCH
        -- Back-fill batch timing for already-completed rows
        UPDATE Audit.ETL_Log
        SET Batch_End_Time = SYSDATETIME(),
            Batch_Duration_Sec = DATEDIFF(SECOND, @Batch_Start, SYSDATETIME())
        WHERE Batch_Id = @Batch_Id
          AND Batch_End_Time IS NULL;

        -- Write failure record
        INSERT INTO Audit.ETL_Log
            (Batch_Id, Layer_Name, Table_Name, Procedure_Name,
             Batch_Start_Time, Load_Start_Time, Load_End_Time,
             Source_Row_Count, Rows_Inserted, Status,
             Error_Message, Error_Number, Error_State)
        VALUES
            (@Batch_Id, 'Silver', @Table_Name, 'Silver.Load_Silver',
             @Batch_Start, @Load_Start, SYSDATETIME(),
             @Source_Count, @Rows_Inserted, 'FAILED',
             ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_STATE());

        PRINT '=================================================';
        PRINT '    Error Occurred During Loading Silver Layer';
        PRINT '=================================================';
        
        THROW;   -- Re-raise so the calling agent sees a failure
    END CATCH
END
GO