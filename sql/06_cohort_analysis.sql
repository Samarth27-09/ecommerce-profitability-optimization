-- =============================================================================
-- COHORT ANALYSIS - PHASE 5
-- =============================================================================
-- Purpose: Analyze customer retention by grouping customers by first purchase month
-- Author: Data Analytics Portfolio Project
-- Date: Created for Olist E-commerce Analysis
--
-- Cohort Analysis Explanation:
-- - Group customers by the month they made their first purchase (cohort)
-- - Track how many return in subsequent months (retention)
-- - Identify patterns in customer behavior over time
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 1: IDENTIFY EACH CUSTOMER'S FIRST PURCHASE DATE (COHORT ASSIGNMENT)
-- -----------------------------------------------------------------------------
-- Create a table that shows when each customer first purchased

CREATE VIEW customer_cohorts AS
SELECT 
    c.customer_unique_id,
    MIN(o.order_purchase_timestamp) AS first_purchase_date,
    DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    MAX(o.order_purchase_timestamp) AS last_purchase_date
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status IN ('delivered', 'shipped')
GROUP BY c.customer_unique_id
;

-- Let's see our cohort assignments
SELECT 
    'Customer Cohort Assignments Sample' AS analysis_step;

SELECT 
    cohort_month,
    COUNT(*) AS customers_in_cohort,
    MIN(first_purchase_date) AS earliest_purchase,
    MAX(first_purchase_date) AS latest_purchase
FROM customer_cohorts
GROUP BY cohort_month
ORDER BY cohort_month
LIMIT 12;

-- -----------------------------------------------------------------------------
-- STEP 2: CREATE CUSTOMER ACTIVITY BY MONTH
-- -----------------------------------------------------------------------------
-- For each customer, identify which months they made purchases

CREATE VIEW customer_monthly_activity AS
SELECT 
    c.customer_unique_id,
    cc.cohort_month,
    DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month,
    COUNT(DISTINCT o.order_id) AS orders_in_month,
    SUM(oi.price + oi.freight_value) AS revenue_in_month
FROM customers c
JOIN customer_cohorts cc ON c.customer_unique_id = cc.customer_unique_id
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status IN ('delivered', 'shipped')
GROUP BY c.customer_unique_id, cc.cohort_month, DATE_TRUNC('month', o.order_purchase_timestamp)
;

-- -----------------------------------------------------------------------------
-- STEP 3: CALCULATE PERIOD NUMBERS (MONTHS SINCE FIRST PURCHASE)
-- -----------------------------------------------------------------------------
-- Calculate how many months after first purchase each activity occurred

CREATE VIEW cohort_data AS
SELECT 
    cma.customer_unique_id,
    cma.cohort_month,
    cma.activity_month,
    cma.orders_in_month,
    cma.revenue_in_month,
    
    -- Calculate period number (0 = first month, 1 = second month, etc.)
    EXTRACT(YEAR FROM cma.activity_month) * 12 + EXTRACT(MONTH FROM cma.activity_month) - 
    (EXTRACT(YEAR FROM cma.cohort_month) * 12 + EXTRACT(MONTH FROM cma.cohort_month)) AS period_number

FROM customer_monthly_activity cma
;

-- Let's see our period calculations
SELECT 
    'Period Number Calculations Sample' AS analysis_step;

SELECT 
    customer_unique_id,
    cohort_month,
    activity_month,
    period_number,
    orders_in_month
FROM cohort_data
WHERE customer_unique_id IN (
    SELECT customer_unique_id 
    FROM cohort_data 
    WHERE period_number > 0 
    LIMIT 5
)
ORDER BY customer_unique_id, period_number
LIMIT 20;

-- -----------------------------------------------------------------------------
-- STEP 4: BUILD COHORT TABLE - CUSTOMER COUNTS
-- -----------------------------------------------------------------------------
-- Create the classic cohort retention table showing customer counts

SELECT 
    'Cohort Retention Table - Customer Counts' AS analysis_step;

-- First, let's see cohort sizes
SELECT 
    cohort_month,
    COUNT(DISTINCT customer_unique_id) AS cohort_size
FROM customer_cohorts
GROUP BY cohort_month
ORDER BY cohort_month;

-- Now the full cohort table (first 12 months)
SELECT 
    cohort_month,
    COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END) AS month_0,
    COUNT(DISTINCT CASE WHEN period_number = 1 THEN customer_unique_id END) AS month_1,
    COUNT(DISTINCT CASE WHEN period_number = 2 THEN customer_unique_id END) AS month_2,
    COUNT(DISTINCT CASE WHEN period_number = 3 THEN customer_unique_id END) AS month_3,
    COUNT(DISTINCT CASE WHEN period_number = 4 THEN customer_unique_id END) AS month_4,
    COUNT(DISTINCT CASE WHEN period_number = 5 THEN customer_unique_id END) AS month_5,
    COUNT(DISTINCT CASE WHEN period_number = 6 THEN customer_unique_id END) AS month_6,
    COUNT(DISTINCT CASE WHEN period_number = 7 THEN customer_unique_id END) AS month_7,
    COUNT(DISTINCT CASE WHEN period_number = 8 THEN customer_unique_id END) AS month_8,
    COUNT(DISTINCT CASE WHEN period_number = 9 THEN customer_unique_id END) AS month_9,
    COUNT(DISTINCT CASE WHEN period_number = 10 THEN customer_unique_id END) AS month_10,
    COUNT(DISTINCT CASE WHEN period_number = 11 THEN customer_unique_id END) AS month_11
FROM cohort_data
GROUP BY cohort_month
ORDER BY cohort_month;

-- -----------------------------------------------------------------------------
-- STEP 5: COHORT RETENTION PERCENTAGES
-- -----------------------------------------------------------------------------
-- Show retention as percentages (more meaningful for analysis)

SELECT 
    'Cohort Retention Percentages' AS analysis_step;

WITH cohort_table AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END) AS month_0,
        COUNT(DISTINCT CASE WHEN period_number = 1 THEN customer_unique_id END) AS month_1,
        COUNT(DISTINCT CASE WHEN period_number = 2 THEN customer_unique_id END) AS month_2,
        COUNT(DISTINCT CASE WHEN period_number = 3 THEN customer_unique_id END) AS month_3,
        COUNT(DISTINCT CASE WHEN period_number = 4 THEN customer_unique_id END) AS month_4,
        COUNT(DISTINCT CASE WHEN period_number = 5 THEN customer_unique_id END) AS month_5,
        COUNT(DISTINCT CASE WHEN period_number = 6 THEN customer_unique_id END) AS month_6
    FROM cohort_data
    GROUP BY cohort_month
)
SELECT 
    cohort_month,
    month_0 AS cohort_size,
    ROUND(100.0 * month_0 / month_0, 1) AS month_0_pct,  -- Always 100%
    ROUND(100.0 * month_1 / NULLIF(month_0, 0), 1) AS month_1_pct,
    ROUND(100.0 * month_2 / NULLIF(month_0, 0), 1) AS month_2_pct,
    ROUND(100.0 * month_3 / NULLIF(month_0, 0), 1) AS month_3_pct,
    ROUND(100.0 * month_4 / NULLIF(month_0, 0), 1) AS month_4_pct,
    ROUND(100.0 * month_5 / NULLIF(month_0, 0), 1) AS month_5_pct,
    ROUND(100.0 * month_6 / NULLIF(month_0, 0), 1) AS month_6_pct
FROM cohort_table
WHERE month_0 >= 50  -- Only show cohorts with at least 50 customers
ORDER BY cohort_month;

-- -----------------------------------------------------------------------------
-- STEP 6: AVERAGE RETENTION RATES ACROSS ALL COHORTS
-- -----------------------------------------------------------------------------
-- Calculate average retention rates to understand overall business performance

SELECT 
    'Average Retention Rates Across All Cohorts' AS analysis_step;

WITH cohort_table AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END) AS month_0,
        COUNT(DISTINCT CASE WHEN period_number = 1 THEN customer_unique_id END) AS month_1,
        COUNT(DISTINCT CASE WHEN period_number = 2 THEN customer_unique_id END) AS month_2,
        COUNT(DISTINCT CASE WHEN period_number = 3 THEN customer_unique_id END) AS month_3,
        COUNT(DISTINCT CASE WHEN period_number = 4 THEN customer_unique_id END) AS month_4,
        COUNT(DISTINCT CASE WHEN period_number = 5 THEN customer_unique_id END) AS month_5,
        COUNT(DISTINCT CASE WHEN period_number = 6 THEN customer_unique_id END) AS month_6
    FROM cohort_data
    GROUP BY cohort_month
),
cohort_percentages AS (
    SELECT 
        cohort_month,
        month_0,
        CASE WHEN month_0 > 0 THEN 100.0 * month_1 / month_0 ELSE 0 END AS month_1_pct,
        CASE WHEN month_0 > 0 THEN 100.0 * month_2 / month_0 ELSE 0 END AS month_2_pct,
        CASE WHEN month_0 > 0 THEN 100.0 * month_3 / month_0 ELSE 0 END AS month_3_pct,
        CASE WHEN month_0 > 0 THEN 100.0 * month_4 / month_0 ELSE 0 END AS month_4_pct,
        CASE WHEN month_0 > 0 THEN 100.0 * month_5 / month_0 ELSE 0 END AS month_5_pct,
        CASE WHEN month_0 > 0 THEN 100.0 * month_6 / month_0 ELSE 0 END AS month_6_pct
    FROM cohort_table
    WHERE month_0 >= 20  -- Only include significant cohorts
)
SELECT 
    'Month 1' AS period,
    ROUND(AVG(month_1_pct), 1) AS avg_retention_rate,
    COUNT(*) AS cohorts_included
FROM cohort_percentages
WHERE month_1_pct > 0

UNION ALL

SELECT 
    'Month 2' AS period,
    ROUND(AVG(month_2_pct), 1) AS avg_retention_rate,
    COUNT(*) AS cohorts_included
FROM cohort_percentages
WHERE month_2_pct > 0

UNION ALL

SELECT 
    'Month 3' AS period,
    ROUND(AVG(month_3_pct), 1) AS avg_retention_rate,
    COUNT(*) AS cohorts_included
FROM cohort_percentages
WHERE month_3_pct > 0

UNION ALL

SELECT 
    'Month 4' AS period,
    ROUND(AVG(month_4_pct), 1) AS avg_retention_rate,
    COUNT(*) AS cohorts_included
FROM cohort_percentages
WHERE month_4_pct > 0

UNION ALL

SELECT 
    'Month 5' AS period,
    ROUND(AVG(month_5_pct), 1) AS avg_retention_rate,
    COUNT(*) AS cohorts_included
FROM cohort_percentages
WHERE month_5_pct > 0

UNION ALL

SELECT 
    'Month 6' AS period,
    ROUND(AVG(month_6_pct), 1) AS avg_retention_rate,
    COUNT(*) AS cohorts_included
FROM cohort_percentages
WHERE month_6_pct > 0;

-- -----------------------------------------------------------------------------
-- STEP 7: REVENUE-BASED COHORT ANALYSIS
-- -----------------------------------------------------------------------------
-- Analyze not just customer retention, but revenue retention

SELECT 
    'Cohort Revenue Analysis' AS analysis_step;

WITH cohort_revenue AS (
    SELECT 
        cohort_month,
        period_number,
        COUNT(DISTINCT customer_unique_id) AS active_customers,
        SUM(revenue_in_month) AS total_revenue,
        AVG(revenue_in_month) AS avg_revenue_per_customer
    FROM cohort_data
    WHERE period_number <= 6  -- First 6 months
    GROUP BY cohort_month, period_number
)
SELECT 
    cohort_month,
    ROUND(SUM(CASE WHEN period_number = 0 THEN total_revenue END), 2) AS revenue_month_0,
    ROUND(SUM(CASE WHEN period_number = 1 THEN total_revenue END), 2) AS revenue_month_1,
    ROUND(SUM(CASE WHEN period_number = 2 THEN total_revenue END), 2) AS revenue_month_2,
    ROUND(SUM(CASE WHEN period_number = 3 THEN total_revenue END), 2) AS revenue_month_3,
    ROUND(SUM(CASE WHEN period_number = 4 THEN total_revenue END), 2) AS revenue_month_4,
    ROUND(SUM(CASE WHEN period_number = 5 THEN total_revenue END), 2) AS revenue_month_5,
    ROUND(SUM(CASE WHEN period_number = 6 THEN total_revenue END), 2) AS revenue_month_6
FROM cohort_revenue
GROUP BY cohort_month
ORDER BY cohort_month;

-- -----------------------------------------------------------------------------
-- STEP 8: COHORT INSIGHTS AND BUSINESS IMPLICATIONS
-- -----------------------------------------------------------------------------

SELECT 
    'Cohort Analysis Summary Insights' AS analysis_step;

-- Key metrics summary
WITH cohort_summary AS (
    SELECT 
        COUNT(DISTINCT cohort_month) AS total_cohorts,
        COUNT(DISTINCT customer_unique_id) AS total_customers,
        MIN(cohort_month) AS earliest_cohort,
        MAX(cohort_month) AS latest_cohort
    FROM customer_cohorts
),
retention_summary AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END) AS cohort_size,
        COUNT(DISTINCT CASE WHEN period_number = 1 THEN customer_unique_id END) AS month_1_retained,
        COUNT(DISTINCT CASE WHEN period_number = 3 THEN customer_unique_id END) AS month_3_retained,
        COUNT(DISTINCT CASE WHEN period_number = 6 THEN customer_unique_id END) AS month_6_retained
    FROM cohort_data
    GROUP BY cohort_month
)
SELECT 
    cs.total_cohorts,
    cs.total_customers,
    cs.earliest_cohort,
    cs.latest_cohort,
    
    -- Average cohort size
    ROUND(AVG(rs.cohort_size), 0) AS avg_cohort_size,
    
    -- Average retention rates
    ROUND(AVG(CASE WHEN rs.cohort_size > 0 THEN 100.0 * rs.month_1_retained / rs.cohort_size END), 1) AS avg_month_1_retention,
    ROUND(AVG(CASE WHEN rs.cohort_size > 0 THEN 100.0 * rs.month_3_retained / rs.cohort_size END), 1) AS avg_month_3_retention,
    ROUND(AVG(CASE WHEN rs.cohort_size > 0 THEN 100.0 * rs.month_6_retained / rs.cohort_size END), 1) AS avg_month_6_retention

FROM cohort_summary cs
CROSS JOIN retention_summary rs
GROUP BY cs.total_cohorts, cs.total_customers, cs.earliest_cohort, cs.latest_cohort;

-- -----------------------------------------------------------------------------
-- STEP 9: IDENTIFY BEST AND WORST PERFORMING COHORTS
-- -----------------------------------------------------------------------------

SELECT 
    'Best and Worst Performing Cohorts' AS analysis_step;

-- Best performing cohorts (highest retention)
WITH cohort_performance AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END) AS cohort_size,
        COUNT(DISTINCT CASE WHEN period_number = 1 THEN customer_unique_id END) AS month_1_retained,
        COUNT(DISTINCT CASE WHEN period_number = 3 THEN customer_unique_id END) AS month_3_retained,
        CASE 
            WHEN COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END) > 0 
            THEN 100.0 * COUNT(DISTINCT CASE WHEN period_number = 1 THEN customer_unique_id END) / 
                 COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END)
            ELSE 0 
        END AS month_1_retention_rate,
        CASE 
            WHEN COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END) > 0 
            THEN 100.0 * COUNT(DISTINCT CASE WHEN period_number = 3 THEN customer_unique_id END) / 
                 COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END)
            ELSE 0 
        END AS month_3_retention_rate
    FROM cohort_data
    GROUP BY cohort_month
    HAVING COUNT(DISTINCT CASE WHEN period_number = 0 THEN customer_unique_id END) >= 30
)
-- Top 5 best performing cohorts
SELECT 
    'BEST PERFORMING' AS performance_type,
    cohort_month,
    cohort_size,
    ROUND(month_1_retention_rate, 1) AS month_1_retention_pct,
    ROUND(month_3_retention_rate, 1) AS month_3_retention_pct
FROM cohort_performance
ORDER BY month_3_retention_rate DESC
LIMIT 5

UNION ALL

-- Bottom 5 worst performing cohorts  
SELECT 
    'WORST PERFORMING' AS performance_type,
    cohort_month,
    cohort_size,
    ROUND(month_1_retention_rate, 1) AS month_1_retention_pct,
    ROUND(month_3_retention_rate, 1) AS month_3_retention_pct
FROM cohort_performance
ORDER BY month_3_retention_rate ASC
LIMIT 5;

-- =============================================================================
-- SUMMARY: KEY COHORT ANALYSIS INSIGHTS FOR YOUR PORTFOLIO
-- =============================================================================
/*
This Cohort Analysis helps you understand:

1. CUSTOMER RETENTION PATTERNS
   - How many customers return after their first purchase?
   - Which months have the best/worst retention rates?
   - Is retention improving or declining over time?

2. BUSINESS HEALTH INDICATORS
   - Low Month 1 retention = Poor first experience
   - Declining retention over time = Competition or product issues
   - High early retention = Good product-market fit

3. REVENUE PREDICTABILITY
   - Cohort revenue patterns help forecast future income
   - Identify which customer acquisition periods were most valuable

4. MARKETING EFFECTIVENESS
   - Compare retention rates across different acquisition periods
   - Identify seasonal patterns in customer behavior

Key Metrics to Watch:
- Month 1 Retention: Should be >15% for healthy e-commerce
- Month 3 Retention: Should be >8% for sustainable growth
- Cohort Revenue: Earlier cohorts should show higher lifetime value

Next Steps:
- Use this data in Power BI for visual cohort heatmaps
- Investigate what made high-performing cohorts successful
- Improve onboarding for new customer cohorts
*/
