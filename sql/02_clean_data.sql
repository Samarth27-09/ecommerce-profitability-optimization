-- ===============================================
-- DATA OVERLOOK AND DATA CLEANING
-- ===============================================

-- ===============================================
-- 1. DATA QUALITY ASSESSMENT
-- ===============================================

-- Check for missing critical data
SELECT 'DATA QUALITY REPORT' as report_section;

-- Missing timestamps in orders
SELECT 
    'Missing purchase timestamps' as issue,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM olist_orders), 2) as percentage
FROM olist_orders 
WHERE order_purchase_timestamp IS NULL

UNION ALL

SELECT 
    'Missing delivery dates' as issue,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM olist_orders), 2) as percentage
FROM olist_orders 
WHERE order_delivered_customer_date IS NULL

UNION ALL

-- Check for zero prices (potential data issues)
SELECT 
    'Zero price items' as issue,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM olist_order_items), 2) as percentage
FROM olist_order_items 
WHERE price = 0

UNION ALL

-- Missing product categories
SELECT 
    'Products without category' as issue,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM olist_products), 2) as percentage
FROM olist_products 
WHERE product_category_name IS NULL;

-- ===============================================
-- 2. CLEAN AND STANDARDIZE DATA
-- ===============================================

-- Create a view with clean orders data
-- Only include delivered orders for profitability analysis
CREATE OR REPLACE VIEW clean_orders AS
SELECT 
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    -- Calculate delivery time metrics
    CASE 
        WHEN order_delivered_customer_date IS NOT NULL 
             AND order_purchase_timestamp IS NOT NULL
        THEN order_delivered_customer_date - order_purchase_timestamp
        ELSE NULL
    END as delivery_time_actual,
    -- Check if delivered on time
    CASE 
        WHEN order_delivered_customer_date IS NOT NULL 
             AND order_estimated_delivery_date IS NOT NULL
        THEN order_delivered_customer_date <= order_estimated_delivery_date
        ELSE NULL
    END as delivered_on_time,
    -- Extract date parts for analysis
    DATE(order_purchase_timestamp) as order_date,
    EXTRACT(YEAR FROM order_purchase_timestamp) as order_year,
    EXTRACT(MONTH FROM order_purchase_timestamp) as order_month,
    EXTRACT(DOW FROM order_purchase_timestamp) as order_day_of_week,
    EXTRACT(QUARTER FROM order_purchase_timestamp) as order_quarter
FROM olist_orders
WHERE order_purchase_timestamp IS NOT NULL
  AND order_status NOT IN ('canceled', 'unavailable');

-- Clean order items with calculated profit metrics
CREATE OR REPLACE VIEW clean_order_items AS
SELECT 
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    -- Basic profit calculation (assumes 30% COGS as industry standard)
    oi.price as revenue,
    oi.price * 0.30 as estimated_cogs,
    oi.price * 0.70 as gross_profit_before_shipping,
    oi.price * 0.70 - oi.freight_value as estimated_net_profit,
    -- Profit margins
    CASE 
        WHEN oi.price > 0 
        THEN ROUND(((oi.price * 0.70 - oi.freight_value) / oi.price) * 100, 2)
        ELSE 0
    END as net_profit_margin_pct,
    -- Shipping cost ratio
    CASE 
        WHEN oi.price > 0 
        THEN ROUND((oi.freight_value / oi.price) * 100, 2)
        ELSE 0
    END as shipping_cost_ratio_pct
FROM olist_order_items oi
WHERE oi.price > 0;  -- Exclude zero-price items

-- Clean products with English categories
CREATE OR REPLACE VIEW clean_products AS
SELECT 
    p.product_id,
    p.product_category_name,
    COALESCE(t.product_category_name_english, 'Other') as category_english,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    -- Calculate product volume
    CASE 
        WHEN p.product_length_cm > 0 AND p.product_height_cm > 0 AND p.product_width_cm > 0
        THEN p.product_length_cm * p.product_height_cm * p.product_width_cm
        ELSE NULL
    END as product_volume_cm3
FROM olist_products p
LEFT JOIN product_category_translation t 
    ON p.product_category_name = t.product_category_name;

-- ===============================================
-- 3. CREATE MASTER FACT TABLE FOR ANALYSIS
-- ===============================================

-- Main fact table combining orders, items, products, customers
CREATE OR REPLACE VIEW fact_orders AS
SELECT 
    -- Order information
    co.order_id,
    co.customer_id,
    co.order_status,
    co.order_date,
    co.order_year,
    co.order_month,
    co.order_quarter,
    co.order_day_of_week,
    co.delivered_on_time,
    
    -- Item information
    coi.order_item_id,
    coi.product_id,
    coi.seller_id,
    
    -- Financial metrics
    coi.price as item_price,
    coi.freight_value as shipping_cost,
    coi.revenue,
    coi.estimated_cogs,
    coi.gross_profit_before_shipping,
    coi.estimated_net_profit,
    coi.net_profit_margin_pct,
    coi.shipping_cost_ratio_pct,
    
    -- Product information
    cp.category_english as product_category,
    cp.product_weight_g,
    cp.product_volume_cm3,
    
    -- Customer location
    c.customer_state,
    c.customer_city,
    
    -- Seller location
    s.seller_state,
    s.seller_city
    
FROM clean_orders co
JOIN clean_order_items coi ON co.order_id = coi.order_id
JOIN clean_products cp ON coi.product_id = cp.product_id
JOIN olist_customers c ON co.customer_id = c.customer_id
JOIN olist_sellers s ON coi.seller_id = s.seller_id;

-- ===============================================
-- 4. CREATE SUMMARY TABLES FOR QUICK ANALYSIS
-- ===============================================

-- Monthly profit summary
CREATE OR REPLACE VIEW monthly_profits AS
SELECT 
    order_year,
    order_month,
    COUNT(DISTINCT order_id) as total_orders,
    COUNT(order_item_id) as total_items,
    ROUND(SUM(revenue), 2) as total_revenue,
    ROUND(SUM(shipping_cost), 2) as total_shipping_cost,
    ROUND(SUM(estimated_net_profit), 2) as
