Use [olist-ecommerce]
DROP TABLE IF EXISTS Gold.Dim_Date;
CREATE TABLE Gold.Dim_Date (
    date_key            INT             NOT NULL,
    full_date           DATE            NOT NULL,
    year_number         SMALLINT        NOT NULL,
    quarter_number      TINYINT         NOT NULL,
    month_number        TINYINT         NOT NULL,
    month_name          NVARCHAR(10)    NOT NULL,
    day_name            NVARCHAR(10)    NOT NULL,
    is_weekend          BIT             NOT NULL    DEFAULT 0,
    load_date_timestamp DATETIME2       NOT NULL    DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Gold_Dim_Date PRIMARY KEY (date_key)
);

-- 2. Dim_Products
DROP TABLE IF EXISTS Gold.Dim_Products;
CREATE TABLE Gold.Dim_Products (
    product_id          VARCHAR(50)     NOT NULL,
    category_name_pt    NVARCHAR(100)   NULL,
    category_name_en    NVARCHAR(100)   NULL,
    name_length         SMALLINT        NULL,
    description_length  INT             NULL,
    photo_count         TINYINT         NULL,
    weight_g            INT             NULL,
    length_cm           SMALLINT        NULL,
    height_cm           SMALLINT        NULL,
    width_cm            SMALLINT        NULL,
    volume_cm3          DECIMAL(18, 2)  NULL,
    load_date_timestamp DATETIME2       NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Gold_Dim_Products PRIMARY KEY (product_id)
);

-- 3. Dim_Customers
DROP TABLE IF EXISTS Gold.Dim_Customers;
CREATE TABLE Gold.Dim_Customers (
    customer_unique_id  VARCHAR(50)     NOT NULL,
    zip_code            VARCHAR(10)     NULL,
    city                NVARCHAR(100)   NULL,
    state               CHAR(2)         NULL,
    latitude            DECIMAL(9, 6)   NULL,
    longitude           DECIMAL(9, 6)   NULL,
    load_date_timestamp DATETIME2       NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Gold_Dim_Customers PRIMARY KEY (customer_unique_id)
);

-- 4. Dim_Sellers
DROP TABLE IF EXISTS Gold.Dim_Sellers;
CREATE TABLE Gold.Dim_Sellers (
    seller_id           VARCHAR(50)     NOT NULL,
    zip_code            VARCHAR(10)     NULL,
    city                NVARCHAR(100)   NULL,
    state               CHAR(2)         NULL,
    latitude            DECIMAL(9, 6)   NULL,
    longitude           DECIMAL(9, 6)   NULL,
    business_segment    NVARCHAR(100)   NULL,
    business_type       NVARCHAR(100)   NULL,
    lead_type           NVARCHAR(100)   NULL,
    behaviour_profile   NVARCHAR(100)   NULL,
    catalog_size        INT             NULL,
    declared_monthly_revenue INT         NULL,
    came_from_marketing BIT             NOT NULL DEFAULT 0,
    load_date_timestamp DATETIME2       NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Gold_Dim_Sellers PRIMARY KEY (seller_id)
);

-- 5. Fact_Orders (يجب إنشاؤه قبل Fact_Order_Items)
DROP TABLE IF EXISTS Gold.Fact_Orders;
CREATE TABLE Gold.Fact_Orders (
    order_id            VARCHAR(50)     NOT NULL,
    customer_unique_id  VARCHAR(50)     NOT NULL,
    purchase_date_key   INT             NOT NULL,
    order_status        NVARCHAR(50)    NULL,
    total_payment       DECIMAL(12, 2)  NULL,
    primary_payment_type NVARCHAR(50)   NULL,
    review_score        TINYINT         NULL,
    review_text         NVARCHAR(MAX)   NULL,
    delivery_days_actual INT            NULL,
    is_late_delivery    BIT             NULL,
    is_invalid_payment  BIT             NOT NULL DEFAULT 0,
    load_date_timestamp DATETIME2       NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Gold_Fact_Orders PRIMARY KEY (order_id),
    CONSTRAINT FK_FO_Customers FOREIGN KEY (customer_unique_id) REFERENCES Gold.Dim_Customers (customer_unique_id),
    CONSTRAINT FK_FO_Date FOREIGN KEY (purchase_date_key) REFERENCES Gold.Dim_Date (date_key)
);

-- 6. Fact_Order_Items
DROP TABLE IF EXISTS Gold.Fact_Order_Items;
CREATE TABLE Gold.Fact_Order_Items (
    order_item_key      INT             NOT NULL,
    order_id            VARCHAR(50)     NOT NULL,
    product_id          VARCHAR(50)     NOT NULL,
    seller_id           VARCHAR(50)     NOT NULL,
    purchase_date_key   INT             NOT NULL,
    order_purchase_timestamp DATETIME2  NULL,
    order_delivered_customer_date DATETIME2 NULL,
    price               DECIMAL(10, 2)  NOT NULL,
    freight_value       DECIMAL(10, 2)  NOT NULL,
    total_item_value    DECIMAL(10, 2)  NOT NULL,
    load_date_timestamp DATETIME2       NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Gold_Fact_Order_Items PRIMARY KEY (order_item_key),
    CONSTRAINT FK_FOI_Products FOREIGN KEY (product_id) REFERENCES Gold.Dim_Products (product_id),
    CONSTRAINT FK_FOI_Sellers FOREIGN KEY (seller_id) REFERENCES Gold.Dim_Sellers (seller_id),
    CONSTRAINT FK_FOI_Date FOREIGN KEY (purchase_date_key) REFERENCES Gold.Dim_Date (date_key),
    CONSTRAINT FK_FOI_Orders FOREIGN KEY (order_id) REFERENCES Gold.Fact_Orders (order_id)
);

-- 7. Fact_Marketing_Funnel
DROP TABLE IF EXISTS Gold.Fact_Marketing_Funnel;
CREATE TABLE Gold.Fact_Marketing_Funnel (
    mql_id              VARCHAR(50)     NOT NULL,
    seller_id           VARCHAR(50)     NULL,
    first_contact_date_key INT          NOT NULL,
    won_date_key        INT             NULL,
    lead_origin         NVARCHAR(100)   NULL,
    landing_page_id     VARCHAR(100)    NULL,
    sdr_id              VARCHAR(50)     NULL,
    sr_id               VARCHAR(50)     NULL,
    is_converted        BIT             NOT NULL DEFAULT 0,
    days_to_close       INT             NULL,
    load_date_timestamp DATETIME2       NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Gold_Fact_Marketing_Funnel PRIMARY KEY (mql_id),
    CONSTRAINT FK_FMF_Sellers FOREIGN KEY (seller_id) REFERENCES Gold.Dim_Sellers (seller_id),
    CONSTRAINT FK_FMF_FirstContactDate FOREIGN KEY (first_contact_date_key) REFERENCES Gold.Dim_Date (date_key),
    CONSTRAINT FK_FMF_WonDate FOREIGN KEY (won_date_key) REFERENCES Gold.Dim_Date (date_key)
);