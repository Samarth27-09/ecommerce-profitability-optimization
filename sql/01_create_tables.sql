-- =====================================================================
-- CREATING INITIAL TABLES AND LOADING DATA AS PER THE SCHEMA PLANNED  
-- =====================================================================

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS olist_order_payments CASCADE;
DROP TABLE IF EXISTS olist_order_items CASCADE;
DROP TABLE IF EXISTS olist_orders CASCADE;
DROP TABLE IF EXISTS olist_products CASCADE;
DROP TABLE IF EXISTS olist_customers CASCADE;
DROP TABLE IF EXISTS olist_sellers CASCADE;
DROP TABLE IF EXISTS olist_geolocation CASCADE;
DROP TABLE IF EXISTS product_category_translation CASCADE;

-- ===============================================
-- 1. ORDERS TABLE (Main transaction table)
-- ===============================================
CREATE TABLE olist_orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- Add comments for better understanding
COMMENT ON TABLE olist_orders IS 'Main orders table containing order lifecycle information';
COMMENT ON COLUMN olist_orders.order_id IS 'Unique identifier for each order';
COMMENT ON COLUMN olist_orders.customer_id IS 'Links to customer who placed the order';
COMMENT ON COLUMN olist_orders.order_status IS 'Current status: delivered, shipped, canceled, etc.';

-- ===============================================
-- 2. ORDER ITEMS TABLE (Individual products in orders)
-- ===============================================
CREATE TABLE olist_order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date TIMESTAMP,
    price DECIMAL(10,2) NOT NULL,
    freight_value DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

COMMENT ON TABLE olist_order_items IS 'Individual items within each order - key for revenue calculation';
COMMENT ON COLUMN olist_order_items.price IS 'Selling price of the item (revenue)';
COMMENT ON COLUMN olist_order_items.freight_value IS 'Shipping cost for this item';

-- ===============================================
-- 3. PRODUCTS TABLE (Product catalog information)
-- ===============================================
CREATE TABLE olist_products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(50),
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

COMMENT ON TABLE olist_products IS 'Product catalog with dimensions and category info';
COMMENT ON COLUMN olist_products.product_category_name IS 'Category in Portuguese - use translation table';

-- ===============================================
-- 4. ORDER PAYMENTS TABLE (Payment information)
-- ===============================================
CREATE TABLE olist_order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type VARCHAR(20) NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

COMMENT ON TABLE olist_order_payments IS 'Payment details - multiple payments possible per order';
COMMENT ON COLUMN olist_order_payments.payment_value IS 'Payment amount for this installment';

-- ===============================================
-- 5. CUSTOMERS TABLE (Customer information)
-- ===============================================
CREATE TABLE olist_customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(50),
    customer_state VARCHAR(5)
);

COMMENT ON TABLE olist_customers IS 'Customer information including location';
COMMENT ON COLUMN olist_customers.customer_unique_id IS 'True unique customer (can have multiple customer_ids)';

-- ===============================================
-- 6. SELLERS TABLE (Seller information)
-- ===============================================
CREATE TABLE olist_sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(50),
    seller_state VARCHAR(5)
);

COMMENT ON TABLE olist_sellers IS 'Seller information including location';

-- ===============================================
-- 7. GEOLOCATION TABLE (Zip code coordinates)
-- ===============================================
CREATE TABLE olist_geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(10,8),
    geolocation_lng DECIMAL(11,8),
    geolocation_city VARCHAR(50),
    geolocation_state VARCHAR(5)
);

COMMENT ON TABLE olist_geolocation IS 'Geographic coordinates for zip codes';

-- ===============================================
-- 8. PRODUCT CATEGORY TRANSLATION TABLE
-- ===============================================
CREATE TABLE product_category_translation (
    product_category_name VARCHAR(50) PRIMARY KEY,
    product_category_name_english VARCHAR(50) NOT NULL
);

COMMENT ON TABLE product_category_translation IS 'Translation from Portuguese to English categories';

-- ===============================================
-- CREATE INDEXES for better query performance
-- ===============================================

-- Primary business queries will filter by date, so index timestamps
CREATE INDEX idx_orders_purchase_date ON olist_orders (order_purchase_timestamp);
CREATE INDEX idx_orders_delivered_date ON olist_orders (order_delivered_customer_date);
CREATE INDEX idx_orders_status ON olist_orders (order_status);

-- Order items are frequently joined with orders and products
CREATE INDEX idx_order_items_product ON olist_order_items (product_id);
CREATE INDEX idx_order_items_seller ON olist_order_items (seller_id);

-- Customer analysis will group by location
CREATE INDEX idx_customers_state ON olist_customers (customer_state);
CREATE INDEX idx_customers_unique ON olist_customers (customer_unique_id);

-- Product category analysis
CREATE INDEX idx_products_category ON olist_products (product_category_name);

-- Payment type analysis
CREATE INDEX idx_payments_type ON olist_order_payments (payment_type);

-- ===============================================
-- ADD FOREIGN KEY CONSTRAINTS
-- ===============================================

-- Link order items to orders
ALTER TABLE olist_order_items 
ADD CONSTRAINT fk_order_items_orders 
FOREIGN KEY (order_id) REFERENCES olist_orders (order_id);

-- Link order payments to orders
ALTER TABLE olist_order_payments 
ADD CONSTRAINT fk_payments_orders 
FOREIGN KEY (order_id) REFERENCES olist_orders (order_id);

-- Link orders to customers
ALTER TABLE olist_orders 
ADD CONSTRAINT fk_orders_customers 
FOREIGN KEY (customer_id) REFERENCES olist_customers (customer_id);

-- Link order items to products
ALTER TABLE olist_order_items 
ADD CONSTRAINT fk_order_items_products 
FOREIGN KEY (product_id) REFERENCES olist_products (product_id);

-- Link order items to sellers
ALTER TABLE olist_order_items 
ADD CONSTRAINT fk_order_items_sellers 
FOREIGN KEY (seller_id) REFERENCES olist_sellers (seller_id);

-- ===============================================
-- DATA IMPORT COMMANDS (Run after creating tables)
-- ===============================================

/*
-- Copy these commands to import your CSV files:
-- Make sure CSV files are in the correct path

COPY olist_orders FROM '/path/to/data/raw/olist_orders_dataset.csv' 
DELIMITER ',' CSV HEADER;

COPY olist_order_items FROM '/path/to/data/raw/olist_order_items_dataset.csv' 
DELIMITER ',' CSV HEADER;

COPY olist_products FROM '/path/to/data/raw/olist_products_dataset.csv' 
DELIMITER ',' CSV HEADER;

COPY olist_order_payments FROM '/path/to/data/raw/olist_order_payments_dataset.csv' 
DELIMITER ',' CSV HEADER;

COPY olist_customers FROM '/path/to/data/raw/olist_customers_dataset.csv' 
DELIMITER ',' CSV HEADER;

COPY olist_sellers FROM '/path/to/data/raw/olist_sellers_dataset.csv' 
DELIMITER ',' CSV HEADER;

COPY olist_geolocation FROM '/path/to/data/raw/olist_geolocation_dataset.csv' 
DELIMITER ',' CSV HEADER;

COPY product_category_translation FROM '/path/to/data/raw/product_category_name_translation.csv' 
DELIMITER ',' CSV HEADER;
*/

-- ===============================================
-- VERIFY DATA IMPORT
-- ===============================================

-- Check record counts for each table
SELECT 'olist_orders' as table_name, COUNT(*) as record_count FROM olist_orders
UNION ALL
SELECT 'olist_order_items', COUNT(*) FROM olist_order_items
UNION ALL
SELECT 'olist_products', COUNT(*) FROM olist_products
UNION ALL
SELECT 'olist_order_payments', COUNT(*) FROM olist_order_payments
UNION ALL
SELECT 'olist_customers', COUNT(*) FROM olist_customers
UNION ALL
SELECT 'olist_sellers', COUNT(*) FROM olist_sellers
UNION ALL
SELECT 'olist_geolocation', COUNT(*) FROM olist_geolocation
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM product_category_translation;

-- Quick data quality check
SELECT 
    'Orders with NULL purchase_timestamp' as check_description,
    COUNT(*) as count
FROM olist_orders 
WHERE order_purchase_timestamp IS NULL

UNION ALL

SELECT 
    'Order items with price = 0',
    COUNT(*)
FROM olist_order_items 
WHERE price = 0

UNION ALL

SELECT 
    'Products without category',
    COUNT(*)
FROM olist_products 
WHERE product_category_name IS NULL;

COMMENT ON DATABASE current_database() IS 'Olist E-commerce Database for Profitability Analysis Project';

-- ===============================================
-- SETUP COMPLETE!
-- Next: Run 02_clean_data.sql
-- ===============================================
