/*
===============================================
   00 — Azure Blob Storage Setup (ONE-TIME)
===============================================

Run this script ONCE against your Olist database BEFORE running
Load_Bronze_Data_AZURE.sql for the first time.

You need to fill in 3 values from the Azure Portal:
    1. YOUR_SAS_TOKEN      → Storage Account → Shared Access Signature
                             Permissions needed: Read, List
                             Allowed resource types: Object, Container
                             Copy the token — it starts with "sv=..."
                             Do NOT include the leading "?" character.

    2. YOUR_STORAGE_ACCOUNT → the name you gave your storage account
                              e.g. "oliststorage"

    3. YOUR_CONTAINER_NAME  → the blob container name
                              e.g. "olist-data"

Your blob container must have this folder structure:
    olist-data/
    ├── CRM/
    │   ├── olist_closed_deals_dataset.csv
    │   ├── olist_customers_dataset.csv
    │   ├── olist_marketing_qualified_leads_dataset.csv
    │   └── olist_order_reviews_dataset.csv
    ├── ERP1/
    │   ├── olist_order_items_dataset.csv
    │   ├── olist_order_payments_dataset.csv
    │   ├── olist_products_dataset.csv
    │   ├── olist_sellers_dataset.csv
    │   └── product_category_name_translation.csv
    └── ERP2/
        ├── olist_geolocation_dataset.csv
        └── olist_orders_dataset.csv
===============================================
*/

Use [olist-ecommerce];
GO

-- Step 1: Database Master Key (required for scoped credentials)
-- Skip if it already exists
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Olist@2026';
    PRINT 'Master Key created.';
END
ELSE
    PRINT 'Master Key already exists — skipped.';
GO

-- Step 2: Scoped Credential using your Blob SAS Token
-- Drop and recreate if you need to rotate the SAS token
-- Use ALTER instead of DROP/CREATE to avoid dependency errors
IF EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = 'OlistBlobCredential')
BEGIN
    ALTER DATABASE SCOPED CREDENTIAL [OlistBlobCredential]
    WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
    -- Ensure the SECRET starts with the '?' character
    SECRET = '?sp=racwdl&st=2026-05-07T21:06:38Z&se=2026-05-15T05:21:38Z&spr=https&sv=2025-11-05&sr=c&sig=LfEZzNc1C7E5Pn%2FGKA3Qfk%2BryOEhfywgTKLavXEKF3I%3D'; 
END
ELSE
BEGIN
    CREATE DATABASE SCOPED CREDENTIAL [OlistBlobCredential]
    WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
    SECRET = '?sp=racwdl&st=2026-05-07T21:06:38Z&se=2026-05-15T05:21:38Z&spr=https&sv=2025-11-05&sr=c&sig=LfEZzNc1C7E5Pn%2FGKA3Qfk%2BryOEhfywgTKLavXEKF3I%3D';
END
GO

-- Step 3: External Data Source pointing at your container
IF EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'OlistBlobStorage')
    DROP EXTERNAL DATA SOURCE OlistBlobStorage;

CREATE EXTERNAL DATA SOURCE OlistBlobStorage
WITH (
    TYPE       = BLOB_STORAGE,
    -- ⚠️ Replace storage account name and container name below
    LOCATION   = 'https://olistecommercedata.blob.core.windows.net/olist-data',
    CREDENTIAL = OlistBlobCredential
);
GO

PRINT '================================================='
PRINT 'Azure Blob External Data Source is ready.'
PRINT 'You can now run Load_Bronze_Data_AZURE.sql'
PRINT '================================================='