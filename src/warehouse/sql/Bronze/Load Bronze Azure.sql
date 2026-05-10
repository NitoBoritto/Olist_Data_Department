/*
===============================================
   Load_Bronze_Data — AZURE SQL VERSION
===============================================

CHANGES FROM LOCAL VERSION:
    1. @BasePath parameter REMOVED — Azure SQL cannot access local file paths.
       Files are read from Azure Blob Storage via the External Data Source
       'OlistBlobStorage' (created in 00_Azure_Blob_Setup_ONE_TIME.sql).

    2. Every BULK INSERT now uses:
           DATA_SOURCE = 'OlistBlobStorage'
       and a blob-relative path like 'CRM/olist_customers_dataset.csv'
       instead of a local Windows path.

    3. CODEPAGE = '65001' REMOVED from all statements.
       This option is NOT supported when DATA_SOURCE is specified.
       Azure SQL handles NVARCHAR encoding natively — no data loss.

    4. Path separators changed from backslash '\\' to forward slash '/'.
       Blob Storage paths always use forward slashes.

    5. FORMAT = 'CSV' added to all tables (required for DATA_SOURCE loads).
       The order_reviews table already had it — now consistent everywhere.

EVERYTHING ELSE IS IDENTICAL to the original procedure.
===============================================
*/

CREATE OR ALTER PROCEDURE Bronze.Load_Bronze
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Batch-level variables ─────────────────────────────────────────
    DECLARE @Batch_Id          UNIQUEIDENTIFIER = NEWID();
    DECLARE @Batch_Start       DATETIME2        = SYSDATETIME();
    DECLARE @Batch_End         DATETIME2;
    DECLARE @Batch_Duration    INT;

    -- ── Table-level variables (reused per table) ──────────────────────
    DECLARE @Table_Name        NVARCHAR(150);
    DECLARE @Load_Start        DATETIME2;
    DECLARE @Load_End          DATETIME2;
    DECLARE @Load_Duration     INT;
    DECLARE @Rows_Inserted     INT;
    DECLARE @Target_Count      INT;
    DECLARE @BulkSQL           NVARCHAR(MAX);

    BEGIN TRY

    PRINT '=================================================';
    PRINT '== Bronze Layer Load Started: ' + CONVERT(NVARCHAR, @Batch_Start, 120);
    PRINT '=================================================';

    PRINT '============================ Loading CRM Tables ============================';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Crm_closed_deals
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Crm_closed_deals';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Crm_closed_deals;

    -- CHANGED: DATA_SOURCE replaces @BasePath, FORMAT='CSV' added, CODEPAGE removed
    SET @BulkSQL = '
        BULK INSERT Bronze.Crm_closed_deals
        FROM ''CRM/olist_closed_deals_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            ROWTERMINATOR  = ''\n'',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Crm_customers_dataset
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Crm_customers_dataset';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Crm_customers_dataset;

    SET @BulkSQL = '
        BULK INSERT Bronze.Crm_customers_dataset
        FROM ''CRM/olist_customers_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Crm_marketing_qualified_leads
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Crm_marketing_qualified_leads';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Crm_marketing_qualified_leads;

    SET @BulkSQL = '
        BULK INSERT Bronze.Crm_marketing_qualified_leads
        FROM ''CRM/olist_marketing_qualified_leads_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Crm_order_reviews
    -- NOTE: FIELDQUOTE kept — multiline quoted fields still need it
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Crm_order_reviews';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Crm_order_reviews;

    SET @BulkSQL = '
        BULK INSERT Bronze.Crm_order_reviews
        FROM ''CRM/olist_order_reviews_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDQUOTE     = ''"'',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    PRINT '============================ Loading ERP1 Tables ============================';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Erp_order_items
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Erp_order_items';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Erp_order_items;

    SET @BulkSQL = '
        BULK INSERT Bronze.Erp_order_items
        FROM ''ERP1/olist_order_items_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Erp_order_payments
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Erp_order_payments';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Erp_order_payments;

    SET @BulkSQL = '
        BULK INSERT Bronze.Erp_order_payments
        FROM ''ERP1/olist_order_payments_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Erp_products
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Erp_products';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Erp_products;

    SET @BulkSQL = '
        BULK INSERT Bronze.Erp_products
        FROM ''ERP1/olist_products_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Erp_sellers
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Erp_sellers';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Erp_sellers;

    SET @BulkSQL = '
        BULK INSERT Bronze.Erp_sellers
        FROM ''ERP1/olist_sellers_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Erp_product_category_name_translation
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Erp_product_category_name_translation';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Erp_product_category_name_translation;

    SET @BulkSQL = '
        BULK INSERT Bronze.Erp_product_category_name_translation
        FROM ''ERP1/product_category_name_translation.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    PRINT '============================ Loading ERP2 Tables ============================';

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Erp_geolocation
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Erp_geolocation';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Erp_geolocation;

    SET @BulkSQL = '
        BULK INSERT Bronze.Erp_geolocation
        FROM ''ERP2/olist_geolocation_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    -- ════════════════════════════════════════════════════════════════
    -- TABLE: Bronze.Erp_orders
    -- ════════════════════════════════════════════════════════════════
    SET @Table_Name  = 'Bronze.Erp_orders';
    SET @Load_Start  = SYSDATETIME();

    PRINT '-- >> Truncating & Inserting: ' + @Table_Name;
    TRUNCATE TABLE Bronze.Erp_orders;

    SET @BulkSQL = '
        BULK INSERT Bronze.Erp_orders
        FROM ''ERP2/olist_orders_dataset.csv''
        WITH (
            DATA_SOURCE    = ''OlistBlobStorage'',
            FORMAT         = ''CSV'',
            FIRSTROW       = 2,
            FIELDTERMINATOR= '','',
            TABLOCK
        );
        SET @Rows = @@ROWCOUNT;';
    EXEC sp_executesql @BulkSQL, N'@Rows INT OUTPUT', @Rows_Inserted OUTPUT;

    SET @Target_Count = @Rows_Inserted;
    SET @Load_End = SYSDATETIME();
    SET @Load_Duration = DATEDIFF(SECOND, @Load_Start, @Load_End);

    INSERT INTO Audit.ETL_Log (Batch_Id, Layer_Name, Table_Name, Procedure_Name, Batch_Start_Time, Load_Start_Time, Load_End_Time, Load_Duration_Sec, Source_Row_Count, Rows_Inserted, Target_Row_Count, Status)
    VALUES (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze', @Batch_Start, @Load_Start, @Load_End, @Load_Duration, NULL, @Rows_Inserted, @Target_Count, 'SUCCESS');
    PRINT '   [OK] Load Duration: ' + CAST(@Load_Duration AS NVARCHAR) + ' Seconds. Rows: ' + CAST(@Rows_Inserted AS NVARCHAR);

    -- ── Batch close ──────────────────────────────────────────────────
    SET @Batch_End      = SYSDATETIME();
    SET @Batch_Duration = DATEDIFF(SECOND, @Batch_Start, @Batch_End);

    UPDATE Audit.ETL_Log
    SET Batch_End_Time      = @Batch_End,
        Batch_Duration_Sec  = @Batch_Duration
    WHERE Batch_Id = @Batch_Id;

    PRINT '=================================================';
    PRINT '      Total Bronze Layer Is Completed';
    PRINT '  ->> Total Load Duration: ' + CAST(@Batch_Duration AS NVARCHAR) + ' Seconds';
    PRINT '=================================================';

    END TRY
    BEGIN CATCH
        UPDATE Audit.ETL_Log
        SET Batch_End_Time     = SYSDATETIME(),
            Batch_Duration_Sec = DATEDIFF(SECOND, @Batch_Start, SYSDATETIME())
        WHERE Batch_Id = @Batch_Id
          AND Batch_End_Time IS NULL;

        INSERT INTO Audit.ETL_Log
            (Batch_Id, Layer_Name, Table_Name, Procedure_Name,
             Batch_Start_Time, Load_Start_Time, Load_End_Time,
             Source_Row_Count, Rows_Inserted, Status,
             Error_Message, Error_Number, Error_State)
        VALUES
            (@Batch_Id, 'Bronze', @Table_Name, 'Bronze.Load_Bronze',
             @Batch_Start, @Load_Start, SYSDATETIME(),
             NULL, @Rows_Inserted, 'FAILED',
             ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_STATE());

        PRINT '=================================================';
        PRINT '    Error Occurred During Loading Bronze Layer';
        PRINT '=================================================';

        THROW;
    END CATCH
END
GO