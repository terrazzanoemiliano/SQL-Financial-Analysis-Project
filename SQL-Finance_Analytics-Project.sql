/*===================================

 Personal Project SQL for finance 
 Dataset: customers / products / orders 
 
 Exercices:
 1) Monthly Revenue, COGS, Gross Margin, Gross Margin %
 2) Top 10 client for Gross Margin 
 3) Gross Margin for product category 
 4) Month-over-month (MoM) revenue growth percentage 
 5) 3-month rolling average of monthly revenue
 6) Top 3 products by revenue within each category 
 7) Revenue bridge YoY (monthly actual vs previous year)
 8) Top 3 products by YoY revenue growth within each category  
 9) Actual vs Budget variance analysis 

===================================*/


-- #1 Exercices --> calculate the metric for Monthly Revenue, COGS, Gross Margin, Gross Margin %
with q_raw_order as (
  SELECT
  o.quantity * o.unit_price as revenue,
  o.quantity * o.unit_cost as cogs,
  strftime('%Y-%m', o.order_date) as month_order
  from orders o  
),

q_clean_order as (
  SELECT
  month_order,
  round(sum(revenue),2) as revenue,
  round(sum(cogs),2) as cogs,
  round(sum(revenue - cogs),2) as gross_margin,
  round(sum(revenue - cogs) *100.0 / nullif(sum(revenue),0),2) as gross_margin_pct
  from q_raw_order
  group by month_order
)


SELECT
*
from q_clean_order
order by month_order;


-- #2 Exercices --> calculate the Top 10 client for Gross Margin 
with q_raw_order as (
  SELECT
  c.customer_name,
  o.quantity * o.unit_price as revenue,
  o.quantity * o.unit_cost as cogs
  from orders 				o
  join customers 				c 
    on c.customer_id = o.customer_id
),

q_clean_order_customer as (
  SELECT
  customer_name,
  round(sum(revenue),2) as revenue,
  round(sum(cogs),2) as cogs,
  round(sum(revenue - cogs),2) as gross_margin
  from q_raw_order
  group by customer_name
),

q_raw_rank as (
  SELECT
  *,
  RANK() over (order by gross_margin desc) as rank_position
  from q_clean_order_customer
)

SELECT
*
from q_raw_rank
where rank_position <= 10
ORDER BY rank_position; 




-- #3 Exercices --> calculate the Gross Margin for product category 
with q_raw_order as ( 
  SELECT
  p.category,
  o.quantity * o.unit_price as revenue,
  o.quantity * o.unit_cost as cogs
  from orders 				o 
  join products 				p 
    on p.product_id = o.product_id
),

q_margin_by_category as (
  SELECT
  category,
  round(sum(revenue),2) as revenue,
  round(sum(cogs),2) as cogs,
  round(sum(revenue - cogs),2) as gross_margin,
  round(sum(revenue - cogs) * 100.0 / nullif(sum(revenue),0),2) as gross_margin_pct 
  from q_raw_order
  group by category
)

SELECT
*
from q_margin_by_category
ORDER by gross_margin_pct desc; 



-- #4 Exercices --> Calculate the month-over-month (MoM) revenue growth percentage 
with q_raw_order as (
  SELECT
  o.quantity * o.unit_price as revenue,
  strftime('%Y-%m', o.order_date) as month_order
  from orders o 
),

q_order_month as (
  SELECT
  month_order,
  round(sum(revenue),2) as revenue 
  from q_raw_order
  group by month_order
),

q_lag_revenue as (
  SELECT
  month_order,
  revenue,
  lag(revenue) over (order by month_order) as prev_month_revenue 
  from q_order_month
)

SELECT
month_order, 
round((revenue - prev_month_revenue) * 100.0 / nullif(prev_month_revenue,0),2) as MoM_growth
from q_lag_revenue
order by month_order;



-- #5 Exercices --> Calculate the 3-month rolling average of monthly revenue
with q_raw_order as (
  SELECT
  o.quantity * o.unit_price as revenue,
  strftime('%Y-%m', o.order_date) as month_order
  from orders o 
),

q_order_month as (
  SELECT
  month_order,
  round(sum(revenue),2) as revenue 
  from q_raw_order
  group by month_order
),

q_final as (
  SELECT
  *,
  avg(revenue) over (order by month_order rows BETWEEN 2 preceding and current row) as rolling_3m_avg_revenue
  from q_order_month
)

SELECT
*
from q_final 
order by month_order;


-- #6 Exercices --> Calculate the top 3 products by revenue within each category
with q_raw_order as (
  SELECT
  o.quantity * o.unit_price as revenue,
  p.category,
  p.product_name
  from orders 				o 
  join products 				p  
    on p.product_id = o.product_id
),

q_revenue_by_category as (
  SELECT
  category,
  product_name,
  round(sum(revenue),2) as revenue
  from q_raw_order
  group by category, product_name
),

q_rank_category as (
  SELECT
  *,
  dense_rank() over (partition by category order by revenue desc) as rank_position
  from q_revenue_by_category
)

SELECT
category,
product_name,
revenue
from q_rank_category
where rank_position <= 3
order by revenue desc, category;


-- #7 Exercices --> Calculate the revenue bridge YoY (monthly actual vs previous year)
with q_raw_order as (
  SELECT
  o.quantity * o.unit_price as revenue,
  strftime('%Y-%m', o.order_date) as month_order
  from orders o 
),

q_clean_revenue_by_month as (
  SELECT
  month_order,
  round(sum(revenue),2) as revenue
  from q_raw_order
  group by month_order
),

q_raw_previous_year_revenue as (
  SELECT
  *,
  lag(revenue,12) over (order by month_order) as previous_year_revenue
  from q_clean_revenue_by_month
),

q_clean_previous_year_revenue as (
  SELECT
  *,
  round(revenue - previous_year_revenue,2) as yoy_change,
  round((revenue - previous_year_revenue) * 100.0 / nullif(previous_year_revenue,0),2) as yoy_growth_pct
  from q_raw_previous_year_revenue
  where previous_year_revenue is not NULL
)

SELECT
*
from q_clean_previous_year_revenue;


-- #8 Exercices --> Calculate the top 3 products by YoY revenue growth within each category 
with q_raw_order as (
  SELECt
  strftime('%Y-%m', o.order_date) as month_order,
  p.product_name,
  p.category,
  o.quantity * o.unit_price as revenue
  from orders 					o 
  join products 				p 
    on p.product_id = o.product_id
),

q_clean_order as (
  SELECT
  month_order,
  category,
  product_name,
  round(sum(revenue),2) as revenue
  from q_raw_order
  group by month_order, category, product_name
),

q_raw_lag_revenue as (
  SELECT
  *,
  lag(revenue,12) over (partition by category, product_name order by month_order) as previous_year_revenue
  from q_clean_order
),

q_clean_lag_revenue as (
  SELECT
  *,
  round(revenue - previous_year_revenue,2) as yoy_change,
  round((revenue - previous_year_revenue) * 100.0 / nullif(previous_year_revenue,0),2) as yoy_growth_pct
  from q_raw_lag_revenue
  WHERE previous_year_revenue IS NOT NULL 
),

q_final as (
  SELECT
  *,
  dense_rank () over (partition by category, month_order order by yoy_growth_pct desc) as rank_position
  from q_clean_lag_revenue
)

SELECT
*
from q_final
where rank_position <= 3
ORDER BY month_order, category, rank_position;


-- Exercise 9 --> Monthly Actual vs Budget revenue variance analysis
with q_raw_order as (
  SELECT
  strftime('%Y-%m', o.order_date) as month_order,
  o.quantity * o.unit_price as revenue
  from orders 		o 
  where strftime('%Y', o.order_date)  = '2024'
),

q_raw_budget_variance as (
  SELECT
  q.month_order,
  round(sum(revenue),2) as revenue,
  b.budget_revenue
  from q_raw_order				q
  join budget_monthly 			b 
    on q.month_order = b.month_order
  group by q.month_order, b.budget_revenue
),

q_clean_budget_variance as (
  SELECT
  month_order,
  revenue,
  budget_revenue,
  round(revenue - budget_revenue,2) as variance,
  round((revenue - budget_revenue) *100.0 / nullif(budget_revenue,0),2) as variance_pct 
  from q_raw_budget_variance
)

SELECT
month_order,
revenue,
budget_revenue,
variance,
variance_pct
from q_clean_budget_variance
ORDER BY month_order; 