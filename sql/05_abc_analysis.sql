-- =============================================================================
-- ABC SKU ANALYSIS - PHASE 6
-- =============================================================================
-- Purpose: Classify products into A, B, C categories based on revenue contribution
-- Author: Data Analytics Portfolio Project
-- Date: Created for Olist E-commerce Analysis
--
-- ABC Analysis Explanation:
-- A Items: Top 20% of products that generate ~80% of revenue (HIGH priority)
-- B Items: Next 30% of products that generate ~15% of revenue (MEDIUM priority)  
-- C Items: Bottom 50% of products that generate ~5% of revenue (LOW priority)
--
-- Goal: Focus inventory and marketing efforts on high-impact products
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 1: CALCULATE PRODUCT PERFORMANCE METRICS
-- -----------------------------------------------------------------------------
-- Get comprehensive metrics for each SKU to support ABC classification

CREATE VIEW product_performance AS
SELECT 
    oi.product_id,
    p.product_category_name,
    p.product_weight_g,
    
    -- Volume metrics
    COUNT(oi.order_item_id) AS total_units_sold,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    
    -- Revenue metrics
    ROUND(SUM(oi.price), 2) AS total_product_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue_with_shipping,
    ROUND(AVG(oi.price), 2) AS avg_unit_price,
    ROUND(AVG(oi.price + oi.freight_value), 2) AS avg_total_price,
    
    -- Profitability metrics (using 65% cost assumption)
    ROUND(SUM(oi.price) * 0.35, 2) AS estimated_gross_profit,
    ROUND(AVG(oi.price) * 0.35, 2) AS avg_profit_per_unit,
    35.0 AS estimated_margin_percent,  -- 35% margin (100% - 65% cost)
    
    -- Time-based metrics
    MIN(o.order_purchase_timestamp) AS first_sale_date,
    MAX(o.order_purchase_timestamp) AS last_sale_date,
    DATE_PART('day', MAX(o.order_purchase_timestamp) - MIN(o.order_purchase_timestamp)) + 1 AS days_on_sale,
    
    -- Performance ratios
    ROUND(
        COUNT(oi.order_item_id) / 
        NULLIF(DATE_PART('day', MAX(o.order_purchase_timestamp) - MIN(o.order_purchase_timestamp)) + 1, 0), 2
    ) AS avg_units_per_day

FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status IN ('delivered', 'shipped')
GROUP BY oi.product_id, p.product_category_name, p.product_weight_g
HAVING COUNT(oi.order_item_id) >= 3  -- At least 3 units sold for statistical relevance
;

-- Let's see our product performance data
SELECT 
    'Product Performance Sample' AS analysis_step;

SELECT *
FROM product_performance
ORDER BY total_product_revenue DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- STEP 2: CALCULATE CUMULATIVE REVENUE AND PERCENTAGES
-- -----------------------------------------------------------------------------
-- Rank products by revenue and calculate cumulative percentages for ABC classification

CREATE VIEW product_abc_base AS
SELECT 
    product_id,
    product_category_name,
    total_units_sold,
    total_product_revenue,
    estimated_gross_profit,
    avg_unit_price,
    
    -- Ranking by revenue
    RANK() OVER (ORDER BY total_product_revenue DESC) AS revenue_rank,
    
    -- Calculate cumulative revenue
    SUM(total_product_revenue) OVER (ORDER BY total_product_revenue DESC ROWS UNBOUNDED PRECEDING) AS cumulative_revenue,
    
    -- Calculate total revenue for percentage calculations
    SUM(total_product_revenue) OVER () AS total_business_revenue,
    
    -- Calculate cumulative percentage
    ROUND(
        100.0 * SUM(total_product_revenue) OVER (ORDER BY total_product_revenue DESC ROWS UNBOUNDED PRECEDING) / 
        SUM(total_product_revenue) OVER (), 2
    ) AS cumulative_revenue_percent,
    
    -- Calculate individual product revenue contribution
    ROUND(
        100.0 * total_product_revenue / SUM(total_product_revenue) OVER (), 4
    ) AS individual_revenue_percent

FROM product_performance
;

-- Let's see the cumulative calculations
SELECT 
    'Cumulative Revenue Calculations Sample' AS analysis_step;

SELECT 
    product_id,
    total_product_revenue,
    revenue_rank,
    cumulative_revenue_percent,
    individual_revenue_percent
FROM product_abc_base
ORDER BY revenue_rank
LIMIT 20;

-- -----------------------------------------------------------------------------
-- STEP 3: ASSIGN ABC CLASSIFICATIONS
-- -----------------------------------------------------------------------------
-- Classify products into A, B, C categories based on cumulative revenue

CREATE VIEW product_abc_classification AS
SELECT 
    product_id,
    product_category_name,
    total_units_sold,
    total_product_revenue,
    estimated_gross_profit,
    avg_unit_price,
    revenue_rank,
    cumulative_revenue_percent,
    individual_revenue_percent,
    
    -- ABC Classification Logic
    CASE 
        WHEN cumulative_revenue_percent <= 80 THEN 'A'  -- Top products contributing to 80% of revenue
        WHEN cumulative_revenue_percent <= 95 THEN 'B'  -- Next products contributing to next 15% of revenue  
        ELSE 'C'  -- Remaining products contributing to last 5% of revenue
    END AS abc_category,
    
    -- Alternative classification by rank percentiles (more traditional approach)
    CASE 
        WHEN revenue_rank <= (SELECT COUNT(*) * 0.20 FROM product_abc_base) THEN 'A_Alt'
        WHEN revenue_rank <= (SELECT COUNT(*) * 0.50 FROM product_abc_base) THEN 'B_Alt'  
        ELSE 'C_Alt'
    END AS abc_category_alternative

FROM product_abc_base
;

-- -----------------------------------------------------------------------------
-- STEP 4: ABC CATEGORY SUMMARY ANALYSIS
-- -----------------------------------------------------------------------------

SELECT 
    'ABC Category Summary' AS analysis_step;

-- Summary statistics for each ABC category
SELECT 
    abc_category,
    COUNT(*) AS product_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS percent_of_products,
    
    -- Revenue metrics
    ROUND(SUM(total_product_revenue), 2) AS total_category_revenue,
    ROUND(SUM(total_product_revenue) * 100.0 / SUM(SUM(total_product_revenue)) OVER(), 1) AS percent_of_revenue,
    ROUND(AVG(total_product_revenue), 2) AS avg_revenue_per_product,
    
    -- Volume metrics
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(total_units_sold), 1) AS avg_units_per_product,
    
    -- Profitability
    ROUND(SUM(estimated_gross_profit), 2) AS total_estimated_profit,
    ROUND(AVG(avg_unit_price), 2) AS avg_unit_price

FROM product_abc_classification
GROUP BY abc_category
ORDER BY 
    CASE abc_category 
        WHEN 'A' THEN 1 
        WHEN 'B' THEN 2 
        WHEN 'C' THEN 3 
    END;

-- -----------------------------------------------------------------------------
-- STEP 5: TOP PRODUCTS IN EACH ABC CATEGORY
-- -----------------------------------------------------------------------------

SELECT 
    'Top Products in Each ABC Category' AS analysis_step;

-- Top 5 products in each category
WITH ranked_products AS (
    SELECT 
        abc_category,
        product_id,
        product_category_name,
        total_product_revenue,
        total_units_sold,
        avg_unit_price,
        estimated_gross_profit,
        ROW_NUMBER() OVER (PARTITION BY abc_category ORDER BY total_product_revenue DESC) as rank_in_category
    FROM product_abc_classification
)
SELECT *
FROM ranked_products
WHERE rank_in_category <= 5
ORDER BY abc_category, rank_in_category;

-- -----------------------------------------------------------------------------
-- STEP 6: IDENTIFY HIGH-REVENUE BUT LOW-MARGIN PRODUCTS
-- -----------------------------------------------------------------------------
-- Find products that sell well but may need pricing optimization

SELECT 
    'High-Revenue Low-Margin Products (Pricing Optimization)' AS analysis_step;

SELECT 
    pac.product_id,
    pac.product_category_name,
    pac.abc_category,
    pac.total_product_revenue,
    pac.total_units_sold,
    pac.avg_unit_price,
    
    -- Get actual margin data from our profit analysis
    pp.avg_profit_per_unit,
    pp.estimated_margin_percent,
    
    -- Optimization potential
    CASE 
        WHEN pac.abc_category = 'A' AND pp.estimated_margin_percent < 25 THEN 'HIGH PRIORITY - A Item with Low Margin'
        WHEN pac.abc_category = 'B' AND pp.estimated_margin_percent < 20 THEN 'MEDIUM PRIORITY - B Item with Low Margin'
        WHEN pac.abc_category = 'A' THEN 'Monitor - A Item with OK Margin'
        ELSE 'Low Priority'
    END AS optimization_priority,
    
    -- Suggested price increase to achieve 30% margin
    ROUND(pac.avg_unit_price / 0.70, 2) AS suggested_price_for_30pct_margin,
    ROUND((pac.avg_unit_price / 0.70) - pac.avg_unit_price, 2) AS suggested_price_increase

FROM product_abc_classification pac
JOIN product_performance pp ON pac.product_id = pp.product_id
WHERE pac.abc_category IN ('A', 'B')  -- Focus on important products only
    AND pac.total_units_sold >= 10  -- Products with sufficient sales volume
ORDER BY 
    CASE pac.abc_category WHEN 'A' THEN 1 WHEN 'B' THEN 2 END,
    pac.total_product_revenue DESC
LIMIT 20;

-- -----------------------------------------------------------------------------
-- STEP 7: CATEGORY-WISE ABC ANALYSIS
-- -----------------------------------------------------------------------------
-- Understand ABC distribution within each product category

SELECT 
    'ABC Analysis by Product Category' AS analysis_step;

SELECT 
    product_category_name,
    abc_category,
    COUNT(*) AS product_count,
    ROUND(SUM(total_product_revenue), 2) AS category_abc_revenue,
    ROUND(AVG(total_product_revenue), 2) AS avg_product_revenue,
    ROUND(AVG(total_units_sold), 1) AS avg_units_sold,
    
    -- Percentage within category
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY product_category_name), 1
    ) AS pct_of_category_products,
    ROUND(
        SUM(total_product_revenue) * 100.0 / SUM(SUM(total_product_revenue)) OVER (PARTITION BY product_category_name), 1
    ) AS pct_of_category_revenue

FROM product_abc_classification
WHERE product_category_name IS NOT NULL
GROUP BY product_category_name, abc_category
ORDER BY product_category_name, abc_category;

-- -----------------------------------------------------------------------------
-- STEP 8: INVENTORY AND BUSINESS RECOMMENDATIONS
-- -----------------------------------------------------------------------------

SELECT 
    'Business Recommendations by ABC Category' AS analysis_step;

SELECT 
    abc_category,
    COUNT(*) AS product_count,
    
    -- Business recommendations based on ABC classification
    CASE abc_category
        WHEN 'A' THEN 'HIGH FOCUS: Ensure high stock levels, premium marketing, customer service priority. Monitor closely for out-of-stock situations.'
        WHEN 'B' THEN 'MEDIUM FOCUS: Moderate stock levels, standard marketing. Good candidates for promotion to increase sales.'
        WHEN 'C' THEN 'LOW FOCUS: Minimal stock, basic marketing. Consider bundling with A/B items or discontinuation if not profitable.'
    END AS inventory_strategy,
    
    CASE abc_category
        WHEN 'A' THEN 'Premium pricing strategy, focus on value-added services, VIP customer treatment'
        WHEN 'B' THEN 'Competitive pricing, bundle deals, cross-selling opportunities'  
        WHEN 'C' THEN 'Cost-plus pricing, clearance strategies, evaluate discontinuation'
    END AS pricing_strategy,
    
    CASE abc_category
        WHEN 'A' THEN 'Dedicated marketing budget, premium placement, influencer partnerships'
        WHEN 'B' THEN 'Standard marketing mix, seasonal promotions, email campaigns'
        WHEN 'C' THEN 'Minimal marketing spend, liquidation sales, exit strategy evaluation'
    END AS marketing_strategy

FROM product_abc_classification
GROUP BY abc_category
ORDER BY abc_category;

-- -----------------------------------------------------------------------------
-- STEP 9: PRODUCTS CANDIDATES FOR DISCONTINUATION
-- -----------------------------------------------------------------------------
-- Identify C-category products that might be discontinued

SELECT 
    'Discontinuation Candidates (C Category Analysis)' AS analysis_step;

SELECT 
    product_id,
    product_category_name,
    total_product_revenue,
    total_units_sold,
    avg_unit_price,
    estimated_gross_profit,
    
    -- Reasons for potential discontinuation
    CASE 
        WHEN total_units_sold <= 5 THEN 'Very Low Volume'
        WHEN estimated_gross_profit <= 50 THEN 'Low Profitability'
        WHEN avg_unit_price <= 20 THEN 'Low Unit Value'
        ELSE 'Other'
    END AS discontinuation_reason,
    
    -- Risk assessment
    CASE 
        WHEN total_units_sold <= 3 AND estimated_gross_profit <= 20 THEN 'HIGH RISK - Consider Immediate Discontinuation'
        WHEN total_units_sold <= 5 OR estimated_gross_profit <= 50 THEN 'MEDIUM RISK - Monitor Closely'
        ELSE 'LOW RISK - Keep with Minimal Investment'
    END AS risk_assessment

FROM product_abc_classification
WHERE abc_category = 'C'
    AND (total_units_sold <= 10 OR estimated_gross_profit <= 100)  -- Focus on truly problematic products
ORDER BY estimated_gross_profit ASC, total_units_sold ASC
LIMIT 25;

-- =============================================================================
-- SUMMARY: KEY ABC ANALYSIS INSIGHTS FOR YOUR PORTFOLIO
-- =============================================================================
/*
This ABC Analysis helps you:

1. PRIORITIZE INVENTORY MANAGEMENT
   - A Items: 20% of products, 80% of revenue - Keep high stock
   - B Items: 30% of products, 15% of revenue - Moderate stock  
   - C Items: 50% of products, 5% of revenue - Minimal stock

2. OPTIMIZE MARKETING SPEND
   - Focus marketing budget on A and B items
   - Use C items for bundle deals or liquidation

3. PRICING STRATEGY
   - A Items: Premium pricing, value-added services
   - B Items: Competitive pricing, promotions
   - C Items: Cost-plus or clearance pricing

4. BUSINESS DECISIONS
   - Identify products for discontinuation (poor performing C items)
   - Find pricing optimization opportunities (high-volume, low-margin items)
   - Resource allocation based on revenue contribution

Key Actions:
- Focus 80% of attention on A items (they drive your business)
- Optimize pricing on high-revenue, low-margin products
- Consider discontinuing underperforming C items
- Use B items for cross-selling and upselling

Next Steps:
- Create Power BI dashboard showing ABC distribution
- Implement different inventory policies for each category
- Set up automated alerts for A-item stock levels
*/
