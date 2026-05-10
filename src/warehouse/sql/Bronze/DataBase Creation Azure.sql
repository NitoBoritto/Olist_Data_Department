/*
===============================================
         Azure SQL — Schema & Audit Setup
===============================================

IMPORTANT — AZURE SQL DIFFERENCE:
    You CANNOT create or drop databases from inside a script on Azure SQL.
    The 'Olist' database must already exist (create it from the Azure Portal
    or Azure CLI before running this script).

    The block below that used:
        USE master;
        ALTER DATABASE Olist SET SINGLE_USER ...   ← NOT SUPPORTED on Azure SQL
        DROP DATABASE Olist;                        ← NOT SUPPORTED via script
        CREATE DATABASE Olist;                      ← NOT SUPPORTED via script

    ...has been REMOVED. Connect directly to your 'Olist' database in SSMS
    (pick it from the connection dialog) and run this script from there.

WHAT THIS SCRIPT DOES:
    - Creates Bronze, Silver, Gold, Audit schemas if they don't exist
    - Creates Audit.ETL_Log table if it doesn't exist
    - Safe to re-run (all statements are idempotent)
===============================================
*/

-- ── Connect directly to your Olist database before running ─────────────
Use [olist-ecommerce];
Go

-- ── Schemas ─────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Bronze')
    EXEC('CREATE SCHEMA Bronze');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Silver')
    EXEC('CREATE SCHEMA Silver');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Gold')
    EXEC('CREATE SCHEMA Gold');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Audit')
    EXEC('CREATE SCHEMA Audit');
GO

-- ── Audit.ETL_Log ────────────────────────────────────────────────────────
IF OBJECT_ID('Audit.ETL_Log','U') IS NULL
BEGIN
    CREATE TABLE Audit.ETL_Log (
        Log_Id               INT           IDENTITY(1,1)  PRIMARY KEY,
        Batch_Id             UNIQUEIDENTIFIER              NOT NULL,
        Layer_Name           NVARCHAR(50)                  NOT NULL,
        Table_Name           NVARCHAR(150)                 NOT NULL,
        Procedure_Name       NVARCHAR(200)                 NULL,
        Batch_Start_Time     DATETIME2                     NULL,
        Batch_End_Time       DATETIME2                     NULL,
        Batch_Duration_Sec   INT                           NULL,
        Load_Start_Time      DATETIME2                     NULL,
        Load_End_Time        DATETIME2                     NULL,
        Load_Duration_Sec    INT                           NULL,
        Source_Row_Count     INT                           NULL,
        Rows_Inserted        INT                           NULL,
        Target_Row_Count     INT                           NULL,
        Status               NVARCHAR(20)                  NOT NULL,
        Error_Message        NVARCHAR(MAX)                 NULL,
        Error_Number         INT                           NULL,
        Error_State          INT                           NULL,
        Created_At           DATETIME2  DEFAULT SYSDATETIME()
    );
END
GO