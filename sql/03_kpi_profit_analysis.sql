-- =============================================================================
-- KPI PROFIT ANALYSIS - PHASE 3
-- =============================================================================
-- Purpose: Calculate key profitability metrics to identify declining margins
-- Author: Data Analytics Portfolio Project
-- Date: Created for Olist E-commerce Analysis
--
-- Key Metrics Calculated:
-- 1. Revenue per order, SKU, and category
-- 2. Estimated costs (65% of price assumption)
-- 3. Profit margins and percentages
-- 4. Top loss-making SKUs identification
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. BASIC REVENUE AND PROFIT CALCULATIONS
-- -----------------------------------------------------------------------------
-- This query creates our main profitability dataset by joining key tables
-- and calculating revenue, estimated costs, and profit for each order item

CREATE VIEW profit_analysis_base AS
SELECT 
    -- Order Information
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    
    -- Product Information  
    p.product_category_name,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    
    -- Order Details
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    
    -- Financial Calculations
    oi.price AS item_price,
    oi.freight_value,
    
    -- Revenue = Price + Freight (total customer payment for this item)
    (oi.price + oi.freight_value) AS total_revenue,
    
    -- Estimated Cost = 65% of item price (industry assumption for e-commerce)
    (oi.price * 0.65) AS estimated_product_cost,
    
    -- Estimated shipping cost = 80% of freight value (logistics cost assumption)
    (oi.freight_value * 0.80) AS estimated_shipping_cost,
    
    -- Total estimated cost = product cost + shipping cost
    ((oi.price * 0.65) + (oi.freight_value * 0.80)) AS total_estimated_cost,
    
    -- Gross Profit = Revenue - Total Costs
    ((oi.price + oi.freight_value) - ((oi.price * 0.65) + (oi.freight_value * 0.80))) AS gross_profit,
    
    -- Profit Margin % = (Gross Profit / Revenue) * 100
    CASE 
        WHEN (oi.price + oi.freight_value) > 0 
        THEN (((oi.price + oi.freight_value) - ((oi.price * 0.65) + (oi.freight_value * 0.80))) / (oi.price + oi.freight_value)) * 100
        ELSE 0
    END AS profit_margin_percent

FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status IN ('delivered', 'shipped', 'processing')  -- Only include valid orders
;

-- -----------------------------------------------------------------------------
-- 2. REVENUE ANALYSIS BY ORDER
-- -----------------------------------------------------------------------------
-- Calculate total revenue, costs, and profit per order

SELECT 
    'Revenue Analysis by Order' AS analysis_type;

SELECT 
    order_id,
    order_purchase_timestamp,
    COUNT(order_item_id) AS total_items_in_order,
    
    -- Revenue metrics
    ROUND(SUM(item_price), 2) AS total_item_value,
    ROUND(SUM(freight_value), 2) AS total_freight,
    ROUND(SUM(total_revenue), 2) AS total_order_revenue,
    
    -- Cost and profit metrics
    ROUND(SUM(total_estimated_cost), 2) AS total_estimated_cost,
    ROUND(SUM(gross_profit), 2) AS total_gross_profit,
    ROUND(AVG(profit_margin_percent), 2) AS avg_profit_margin_percent,
    
    -- Order profitability classification
    CASE 
        WHEN SUM(gross_profit) > 50 THEN 'High Profit'
        WHEN SUM(gross_profit) > 10 THEN 'Medium Profit'  
        WHEN SUM(gross_profit) > 0 THEN 'Low Profit'
        ELSE 'Loss Making'
    END AS profit_category

FROM profit_analysis_base
GROUP BY order_id, order_purchase_timestamp
ORDER BY total_gross_profit DESC
LIMIT 20;  -- Show top 20 most profitable orders

-- -----------------------------------------------------------------------------
-- 3. REVENUE ANALYSIS BY SKU (PRODUCT)
-- -----------------------------------------------------------------------------
-- Identify which products are most/least profitable

SELECT 
    'Revenue Analysis by SKU (Product)' AS analysis_type;

SELECT 
    product_id,
    product_category_name,
    
    -- Volume metrics
    COUNT(order_item_id) AS total_units_sold,
    
    -- Revenue metrics
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(AVG(total_revenue), 2) AS avg_revenue_per_unit,
    
    -- Cost and profit metrics
    ROUND(SUM(total_estimated_cost), 2) AS total_estimated_cost,
    ROUND(SUM(gross_profit), 2) AS total_gross_profit,
    ROUND(AVG(gross_profit), 2) AS avg_profit_per_unit,
    ROUND(AVG(profit_margin_percent), 2) AS avg_profit_margin_percent,
    
    -- Profitability ranking
    RANK() OVER (ORDER BY SUM(gross_profit) DESC) AS profit_rank

FROM profit_analysis_base
GROUP BY product_id, product_category_name
HAVING COUNT(order_item_id) >= 5  -- Only include products sold at least 5 times
ORDER BY total_gross_profit DESC
LIMIT 50;  -- Top 50 most profitable SKUs

-- -----------------------------------------------------------------------------
-- 4. REVENUE ANALYSIS BY CATEGORY
-- -----------------------------------------------------------------------------
-- Understand category-level profitability trends

SELECT 
    'Revenue Analysis by Category' AS analysis_type;

SELECT 
    product_category_name,
    
    -- Volume metrics
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(order_item_id) AS total_units_sold,
    
    -- Revenue metrics
    ROUND(SUM(total_revenue), 2) AS total_category_revenue,
    ROUND(AVG(total_revenue), 2) AS avg_revenue_per_unit,
    
    -- Cost and profit metrics  
    ROUND(SUM(total_estimated_cost), 2) AS total_estimated_cost,
    ROUND(SUM(gross_profit), 2) AS total_gross_profit,
    ROUND(AVG(profit_margin_percent), 2) AS avg_profit_margin_percent,
    
    -- Market share calculation
    ROUND(
        (SUM(total_revenue) / (SELECT SUM(total_revenue) FROM profit_analysis_base) * 100), 2
    ) AS revenue_market_share_percent

FROM profit_analysis_base
WHERE product_category_name IS NOT NULL
GROUP BY product_category_name
ORDER BY total_gross_profit DESC;

-- -----------------------------------------------------------------------------
-- 5. TOP 10 LOSS-MAKING SKUs IDENTIFICATION
-- -----------------------------------------------------------------------------
-- Critical analysis: Find products that are losing money

SELECT 
    'TOP 10 LOSS-MAKING SKUs' AS analysis_type;

SELECT 
    product_id,
    product_category_name,
    
    -- Volume sold (important for impact assessment)
    COUNT(order_item_id) AS total_units_sold,
    
    -- Financial impact
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(total_estimated_cost), 2) AS total_estimated_cost,
    ROUND(SUM(gross_profit), 2) AS total_loss,  -- This will be negative
    ROUND(AVG(profit_margin_percent), 2) AS avg_margin_percent,
    
    -- Per unit analysis
    ROUND(AVG(item_price), 2) AS avg_selling_price,
    ROUND(AVG(estimated_product_cost), 2) AS avg_product_cost,
    ROUND(AVG(freight_value), 2) AS avg_freight_value,
    
    -- Priority level for fixing
    CASE 
        WHEN COUNT(order_item_id) >= 20 THEN 'HIGH PRIORITY - High Volume Loss'
        WHEN COUNT(order_item_id) >= 10 THEN 'MEDIUM PRIORITY - Medium Volume Loss'  
        ELSE 'LOW PRIORITY - Low Volume Loss'
    END AS fix_priority

FROM profit_analysis_base
GROUP BY product_id, product_category_name
HAVING SUM(gross_profit) < 0  -- Only loss-making products
ORDER BY SUM(gross_profit) ASC  -- Most negative first (biggest losses)
LIMIT 10;

-- -----------------------------------------------------------------------------
-- 6. MONTHLY PROFITABILITY TREND ANALYSIS
-- -----------------------------------------------------------------------------
-- Track how profitability changes over time to identify declining margins

SELECT 
    'Monthly Profitability Trends' AS analysis_type;

SELECT 
    DATE_TRUNC('month', order_purchase_timestamp) AS order_month,
    
    -- Volume metrics
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(order_item_id) AS total_items_sold,
    
    -- Revenue and profit trends
    ROUND(SUM(total_revenue), 2) AS monthly_revenue,
    ROUND(SUM(gross_profit), 2) AS monthly_gross_profit,
    ROUND(AVG(profit_margin_percent), 2) AS avg_monthly_margin_percent,
    
    -- Month-over-month comparison (simple calculation)
    ROUND(SUM(total_revenue) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS avg_revenue_per_order,
    ROUND(SUM(gross_profit) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS avg_profit_per_order

FROM profit_analysis_base
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY order_month;

-- -----------------------------------------------------------------------------
-- 7. HIGH-REVENUE BUT LOW-MARGIN PRODUCTS (PRICING OPTIMIZATION CANDIDATES)
-- -----------------------------------------------------------------------------
-- Find products that sell well but have poor margins - prime candidates for price optimization

SELECT 
    'High-Revenue Low-Margin Products (Pricing Optimization Candidates)' AS analysis_type;

SELECT 
    product_id,
    product_category_name,
    
    -- Performance metrics
    COUNT(order_item_id) AS total_units_sold,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(gross_profit), 2) AS total_gross_profit,
    
    -- Key metrics for optimization
    ROUND(AVG(profit_margin_percent), 2) AS avg_profit_margin_percent,
    ROUND(AVG(item_price), 2) AS current_avg_price,
    
    -- Optimization potential calculation
    -- If we could achieve 25% margin, what should the price be?
    ROUND(AVG(estimated_product_cost) / 0.75, 2) AS suggested_price_for_25pct_margin,
    ROUND(
        (AVG(estimated_product_cost) / 0.75) - AVG(item_price), 2
    ) AS price_increase_needed,
    
    -- Revenue rank vs margin rank (to identify high-revenue, low-margin items)
    RANK() OVER (ORDER BY SUM(total_revenue) DESC) AS revenue_rank,
    RANK() OVER (ORDER BY AVG(profit_margin_percent) ASC) AS margin_rank

FROM profit_analysis_base
GROUP BY product_id, product_category_name
HAVING 
    COUNT(order_item_id) >= 10  -- Sold at least 10 units (statistical significance)
    AND SUM(total_revenue) >= 1000  -- High revenue products
    AND AVG(profit_margin_percent) < 20  -- Low margin products (less than 20%)
ORDER BY total_revenue DESC
LIMIT 15;

-- -----------------------------------------------------------------------------
-- 8. SUMMARY INSIGHTS FOR BUSINESS ACTION
-- -----------------------------------------------------------------------------
-- Executive summary of key findings

SELECT 
    'EXECUTIVE SUMMARY - KEY FINDINGS' AS analysis_type;

-- Overall business health metrics
SELECT 
    'Overall Business Health' AS metric_category,
    COUNT(DISTINCT order_id) AS total_orders_analyzed,
    COUNT(DISTINCT product_id) AS total_unique_products,
    ROUND(SUM(total_revenue), 2) AS total_business_revenue,
    ROUND(SUM(gross_profit), 2) AS total_gross_profit,
    ROUND(AVG(profit_margin_percent), 2) AS overall_avg_margin_percent,
    
    -- Problem identification
    ROUND(
        (SELECT COUNT(*) FROM (
            SELECT product_id FROM profit_analysis_base 
            GROUP BY product_id 
            HAVING SUM(gross_profit) < 0
        ) loss_products) * 100.0 / COUNT(DISTINCT product_id), 2
    ) AS percent_loss_making_products

FROM profit_analysis_base;

-- =============================================================================
-- NOTES FOR NEXT STEPS:
-- =============================================================================
-- 1. Run this analysis to identify problematic products and categories
-- 2. Use results to inform pricing strategy in Excel simulation (Phase 6)
-- 3. Create Power BI visualizations based on these key metrics
-- 4. Focus on high-revenue, low-margin products for quick wins
-- 5. Consider discontinuing or repricing loss-making products
-- =============================================================================
