Use [olist-ecommerce];

/*
============================
	Creating CRM Tables
============================
*/

-- closed_deals Table
If Object_Id('Silver.Crm_closed_deals','U') Is Not Null
	Drop Table Silver.Crm_closed_deals;

Create Table Silver.Crm_closed_deals(
    mql_id NVARCHAR(50),
    seller_id NVARCHAR(50),
    sdr_id NVARCHAR(50),
    sr_id NVARCHAR(50),
    won_date DATETIME,
    business_segment NVARCHAR(100),
    lead_type NVARCHAR(100),
    lead_behaviour_profile NVARCHAR(100),
    has_company BIT,
    has_gtin BIT,
    average_stock NVARCHAR(50),
    business_type NVARCHAR(50),
    declared_product_catalog_size INT,
    declared_monthly_revenue INT,
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
); 

-- customers Table (Removed '_dataset' to match Load_Silver)
If Object_Id('Silver.Crm_customers','U') Is Not Null
	Drop Table Silver.Crm_customers;

Create Table Silver.Crm_customers(
    customer_id NVARCHAR(50),
    customer_unique_id NVARCHAR(50),
    customer_zip_code_prefix NVARCHAR(20),
    customer_city NVARCHAR(100),
    customer_state NVARCHAR(10),
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);

-- marketing_qualified_leads Table
If Object_Id('Silver.Crm_marketing_qualified_leads','U') Is Not Null
	Drop Table Silver.Crm_marketing_qualified_leads;

Create Table Silver.Crm_marketing_qualified_leads(
    mql_id NVARCHAR(50),
    first_contact_date DATETIME,
    landing_page_id NVARCHAR(50),
    origin NVARCHAR(50),
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);

-- order_reviews Table
If Object_Id('Silver.Crm_order_reviews','U') Is Not Null
	Drop Table Silver.Crm_order_reviews;

Create Table Silver.Crm_order_reviews(
    review_id NVARCHAR(50),
    order_id NVARCHAR(50),
    review_score INT,
    review_comment_title NVARCHAR(MAX),
    review_comment_message NVARCHAR(MAX),
    review_creation_date DATETIME2,
    review_answer_timestamp DATETIME2,
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);

/*
============================
	Creating ERP1 Tables
============================
*/

-- order_items Table
If Object_Id('Silver.Erp_order_items','U') Is Not Null
	Drop Table Silver.Erp_order_items;

Create Table Silver.Erp_order_items(
    order_id NVARCHAR(50),
    order_item_number INT,
    order_item_key INT,
    product_id NVARCHAR(50),
    seller_id NVARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(12,2),
    freight_value DECIMAL(12,2),
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);

-- order_payments Table 
If Object_Id('Silver.Erp_order_payments','U') Is Not Null
	Drop Table Silver.Erp_order_payments;

Create Table Silver.Erp_order_payments(
    order_id NVARCHAR(50),
    payment_sequential INT,
    payment_type NVARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(12,2),
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);

-- products Table
If Object_Id('Silver.Erp_products','U') Is Not Null
	Drop Table Silver.Erp_products;

Create Table Silver.Erp_products(
    product_id NVARCHAR(50),
    product_category_name NVARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);

-- sellers Table 
If Object_Id('Silver.Erp_sellers','U') Is Not Null
	Drop Table Silver.Erp_sellers;

Create Table Silver.Erp_sellers(
    seller_id NVARCHAR(50),
    seller_zip_code_prefix NVARCHAR(20),
    seller_city NVARCHAR(100),
    seller_state NVARCHAR(10),
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);

-- product_category_name_translation Table
If Object_Id('Silver.Erp_product_category_name_translation','U') Is Not Null
	Drop Table Silver.Erp_product_category_name_translation;

Create Table Silver.Erp_product_category_name_translation (
    product_category_name NVARCHAR(MAX),
    product_category_name_english NVARCHAR(MAX),
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);

/*
============================
	Creating ERP2 Tables
============================
*/

-- geolocation Table
If Object_Id('Silver.Erp_geolocation','U') Is Not Null
	Drop Table Silver.Erp_geolocation;

Create Table Silver.Erp_geolocation(
    geolocation_zip_code_prefix NVARCHAR(20),
    geolocation_lat NUMERIC(18,10),
    geolocation_lng NUMERIC(18,10),
    geolocation_city NVARCHAR(100),
    geolocation_state NVARCHAR(10),
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);

-- orders Table
If Object_Id('Silver.Erp_orders','U') Is Not Null
	Drop Table Silver.Erp_orders;

Create Table Silver.Erp_orders(
    order_id NVARCHAR(50),
    customer_id NVARCHAR(50),
    order_status NVARCHAR(50),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    load_date_timestamp DATETIME2 DEFAULT SYSDATETIME()
);