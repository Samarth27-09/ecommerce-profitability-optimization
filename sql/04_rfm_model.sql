-- =============================================================================
-- RFM CUSTOMER ANALYSIS - PHASE 4
-- =============================================================================
-- Purpose: Segment customers based on Recency, Frequency, and Monetary value
-- Author: Data Analytics Portfolio Project
-- Date: Created for Olist E-commerce Analysis
--
-- RFM Model Explanation:
-- R (Recency): How recently did the customer make a purchase?
-- F (Frequency): How often does the customer make purchases?
-- M (Monetary): How much money does the customer spend?
--
-- Scoring: 1 = Worst, 5 = Best for each dimension
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 1: CALCULATE BASIC RFM METRICS FOR EACH CUSTOMER
-- -----------------------------------------------------------------------------
-- First, we calculate the raw RFM values before scoring

CREATE VIEW customer_rfm_raw AS
SELECT 
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    
    -- RECENCY: Days since last order (lower is better)
    DATE_PART('day', CURRENT_DATE - MAX(o.order_purchase_timestamp)) AS recency_days,
    
    -- FREQUENCY: Total number of orders (higher is better)
    COUNT(DISTINCT o.order_id) AS frequency_orders,
    
    -- MONETARY: Total amount spent (higher is better)
    ROUND(SUM(oi.price + oi.freight_value), 2) AS monetary_total,
    
    -- Additional helpful metrics
    ROUND(AVG(oi.price + oi.freight_value), 2) AS avg_order_value,
    MIN(o.order_purchase_timestamp) AS first_order_date,
    MAX(o.order_purchase_timestamp) AS last_order_date

FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status IN ('delivered', 'shipped')  -- Only successful orders
GROUP BY c.customer_unique_id, c.customer_city, c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 1  -- At least 1 order
;

-- Let's see our raw RFM data
SELECT 
    'Raw RFM Metrics Sample' AS analysis_step;

SELECT *
FROM customer_rfm_raw
ORDER BY monetary_total DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- STEP 2: CALCULATE RFM SCORES USING QUINTILES (1-5 SCALE)
-- -----------------------------------------------------------------------------
-- Convert raw values to scores from 1-5 using percentiles

CREATE VIEW customer_rfm_scores AS
SELECT 
    customer_unique_id,
    customer_city,
    customer_state,
    recency_days,
    frequency_orders,
    monetary_total,
    avg_order_value,
    first_order_date,
    last_order_date,
    
    -- RECENCY SCORE: 5 = Most Recent, 1 = Least Recent
    -- Note: For recency, LOWER days = HIGHER score (reverse logic)
    CASE 
        WHEN recency_days <= (SELECT PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY recency_days) FROM customer_rfm_raw) THEN 5
        WHEN recency_days <= (SELECT PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY recency_days) FROM customer_rfm_raw) THEN 4
        WHEN recency_days <= (SELECT PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY recency_days) FROM customer_rfm_raw) THEN 3
        WHEN recency_days <= (SELECT PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY recency_days) FROM customer_rfm_raw) THEN 2
        ELSE 1
    END AS recency_score,
    
    -- FREQUENCY SCORE: 5 = Most Frequent, 1 = Least Frequent
    CASE 
        WHEN frequency_orders >= (SELECT PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY frequency_orders) FROM customer_rfm_raw) THEN 5
        WHEN frequency_orders >= (SELECT PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY frequency_orders) FROM customer_rfm_raw) THEN 4
        WHEN frequency_orders >= (SELECT PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY frequency_orders) FROM customer_rfm_raw) THEN 3
        WHEN frequency_orders >= (SELECT PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY frequency_orders) FROM customer_rfm_raw) THEN 2
        ELSE 1
    END AS frequency_score,
    
    -- MONETARY SCORE: 5 = Highest Spender, 1 = Lowest Spender
    CASE 
        WHEN monetary_total >= (SELECT PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY monetary_total) FROM customer_rfm_raw) THEN 5
        WHEN monetary_total >= (SELECT PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY monetary_total) FROM customer_rfm_raw) THEN 4
        WHEN monetary_total >= (SELECT PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY monetary_total) FROM customer_rfm_raw) THEN 3
        WHEN monetary_total >= (SELECT PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY monetary_total) FROM customer_rfm_raw) THEN 2
        ELSE 1
    END AS monetary_score

FROM customer_rfm_raw
;

-- Let's see our scored RFM data
SELECT 
    'RFM Scores Sample' AS analysis_step;

SELECT 
    customer_unique_id,
    recency_days,
    frequency_orders,
    monetary_total,
    recency_score,
    frequency_score,
    monetary_score,
    -- Combined RFM Score (simple concatenation)
    CONCAT(recency_score, frequency_score, monetary_score) AS rfm_combined_score
FROM customer_rfm_scores
ORDER BY monetary_total DESC
LIMIT 15;

-- -----------------------------------------------------------------------------
-- STEP 3: CREATE CUSTOMER SEGMENTS BASED ON RFM SCORES
-- -----------------------------------------------------------------------------
-- Group customers into meaningful business segments

CREATE VIEW customer_segments AS
SELECT 
    customer_unique_id,
    customer_city,
    customer_state,
    recency_days,
    frequency_orders,
    monetary_total,
    recency_score,
    frequency_score,
    monetary_score,
    CONCAT(recency_score, frequency_score, monetary_score) AS rfm_score,
    
    -- Customer Segment Classification (Simplified for Beginners)
    CASE 
        -- Champions: Best customers (High RFM)
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
        
        -- Loyal Customers: Buy regularly (High F, good R)
        WHEN frequency_score >= 4 AND recency_score >= 3 THEN 'Loyal Customers'
        
        -- Potential Loyalists: Recent customers with potential (High R, Medium F)
        WHEN recency_score >= 4 AND frequency_score >= 2 AND frequency_score <= 3 THEN 'Potential Loyalists'
        
        -- Big Spenders: High monetary value (High M)
        WHEN monetary_score >= 4 THEN 'Big Spenders'
        
        -- At Risk: Used to be good customers (Low R, High F/M)
        WHEN recency_score <= 2 AND (frequency_score >= 3 OR monetary_score >= 3) THEN 'At Risk'
        
        -- Cannot Lose Them: High monetary but declining (High M, Low R)
        WHEN monetary_score >= 4 AND recency_score <= 2 THEN 'Cannot Lose Them'
        
        -- Hibernating: Last purchase was long ago (Low R, but decent F/M history)
        WHEN recency_score <= 2 AND frequency_score >= 2 THEN 'Hibernating'
        
        -- Lost Customers: Lowest recency and frequency
        WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'Lost Customers'
        
        -- New Customers: Recent but low frequency/monetary
        WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New Customers'
        
        -- Everything else
        ELSE 'Others'
    END AS customer_segment

FROM customer_rfm_scores
;

-- -----------------------------------------------------------------------------
-- STEP 4: SEGMENT ANALYSIS AND BUSINESS INSIGHTS
-- -----------------------------------------------------------------------------

SELECT 
    'Customer Segment Distribution' AS analysis_step;

-- Segment size and value analysis
SELECT 
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage_of_customers,
    
    -- Financial metrics per segment
    ROUND(SUM(monetary_total), 2) AS total_segment_revenue,
    ROUND(AVG(monetary_total), 2) AS avg_customer_value,
    ROUND(AVG(frequency_orders), 1) AS avg_orders_per_customer,
    ROUND(AVG(recency_days), 1) AS avg_days_since_last_order,
    
    -- Revenue contribution
    ROUND(SUM(monetary_total) * 100.0 / SUM(SUM(monetary_total)) OVER(), 2) AS percentage_of_total_revenue

FROM customer_segments
GROUP BY customer_segment
ORDER BY total_segment_revenue DESC;

-- -----------------------------------------------------------------------------
-- STEP 5: TOP CUSTOMERS IN EACH SEGMENT
-- -----------------------------------------------------------------------------

SELECT 
    'Top Customers by Segment' AS analysis_step;

-- Show best customers in each important segment
WITH ranked_customers AS (
    SELECT 
        customer_segment,
        customer_unique_id,
        customer_city,
        customer_state,
        monetary_total,
        frequency_orders,
        recency_days,
        rfm_score,
        ROW_NUMBER() OVER (PARTITION BY customer_segment ORDER BY monetary_total DESC) as rank_in_segment
    FROM customer_segments
    WHERE customer_segment IN ('Champions', 'Loyal Customers', 'Big Spenders', 'At Risk', 'Cannot Lose Them')
)
SELECT *
FROM ranked_customers
WHERE rank_in_segment <= 3  -- Top 3 in each segment
ORDER BY customer_segment, rank_in_segment;

-- -----------------------------------------------------------------------------
-- STEP 6: RFM SCORE DISTRIBUTION ANALYSIS
-- -----------------------------------------------------------------------------

SELECT 
    'RFM Score Distribution' AS analysis_step;

-- Understanding the distribution of our RFM scores
SELECT 
    recency_score,
    frequency_score,
    monetary_score,
    COUNT(*) AS customer_count,
    ROUND(AVG(monetary_total), 2) AS avg_revenue_per_customer,
    ROUND(SUM(monetary_total), 2) AS total_segment_revenue
FROM customer_segments
GROUP BY recency_score, frequency_score, monetary_score
HAVING COUNT(*) >= 5  -- Only show combinations with at least 5 customers
ORDER BY total_segment_revenue DESC
LIMIT 20;

-- -----------------------------------------------------------------------------
-- STEP 7: BUSINESS RECOMMENDATIONS BY SEGMENT
-- -----------------------------------------------------------------------------

SELECT 
    'Business Action Recommendations' AS analysis_step;

SELECT 
    customer_segment,
    COUNT(*) AS customer_count,
    
    -- Recommended actions for each segment
    CASE customer_segment
        WHEN 'Champions' THEN 'Reward them. They can be early adopters for new products and will help promote your brand.'
        WHEN 'Loyal Customers' THEN 'Upsell higher value products. Ask for reviews. Engage them.'
        WHEN 'Potential Loyalists' THEN 'Offer membership or loyalty programs. Recommend related products.'
        WHEN 'Big Spenders' THEN 'Market your most expensive products. Send VIP treatment offers.'
        WHEN 'At Risk' THEN 'Send personalized emails to reconnect. Offer renewals and helpful products.'
        WHEN 'Cannot Lose Them' THEN 'Win them back via renewals or newer products. Provide helpful resources.'
        WHEN 'Hibernating' THEN 'Offer other relevant products and special discounts. Recreate brand value.'
        WHEN 'Lost Customers' THEN 'Revive interest with reach out campaign, ignore otherwise.'
        WHEN 'New Customers' THEN 'Provide on-boarding support, special offers, start building relationship.'
        ELSE 'Monitor and nurture based on behavior patterns.'
    END AS recommended_action,
    
    -- Priority level for marketing efforts
    CASE customer_segment
        WHEN 'Champions' THEN 'HIGH'
        WHEN 'Cannot Lose Them' THEN 'HIGH'
        WHEN 'At Risk' THEN 'HIGH'
        WHEN 'Loyal Customers' THEN 'MEDIUM'
        WHEN 'Big Spenders' THEN 'MEDIUM'
        WHEN 'Potential Loyalists' THEN 'MEDIUM'
        WHEN 'New Customers' THEN 'MEDIUM'
        ELSE 'LOW'
    END AS marketing_priority

FROM customer_segments
GROUP BY customer_segment
ORDER BY 
    CASE customer_segment
        WHEN 'Champions' THEN 1
        WHEN 'Cannot Lose Them' THEN 2
        WHEN 'At Risk' THEN 3
        WHEN 'Loyal Customers' THEN 4
        WHEN 'Big Spenders' THEN 5
        WHEN 'Potential Loyalists' THEN 6
        WHEN 'New Customers' THEN 7
        ELSE 8
    END;

-- =============================================================================
-- SUMMARY: KEY RFM INSIGHTS FOR YOUR PORTFOLIO
-- =============================================================================
/*
This RFM analysis helps you:

1. IDENTIFY YOUR BEST CUSTOMERS
   - Champions and Loyal Customers drive the most value
   - Focus retention efforts on these segments

2. FIND AT-RISK REVENUE
   - "At Risk" and "Cannot Lose Them" segments need immediate attention
   - These represent customers you're about to lose

3. GROWTH OPPORTUNITIES
   - "Potential Loyalists" can be converted to loyal customers
   - "New Customers" need nurturing to increase frequency

4. OPTIMIZE MARKETING SPEND
   - Prioritize high-value segments for campaigns
   - Avoid spending too much on "Lost Customers"

Next Steps:
- Use these segments in your Power BI dashboard
- Create targeted marketing campaigns for each segment
- Track segment migration over time (are customers moving up or down?)
*/
