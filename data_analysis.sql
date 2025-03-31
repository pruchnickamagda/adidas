--
--Magda Tuczynska Adidas Case Study 01.04.2025

------------- Explanatory Analysis ------------------
-- Checking channels
-- The data contains only fact data for brokers which I assume to be wholesalers or distributor (e.g. Decathlon)
select d.*, f.channel_id as fact_channel_id from dim_channel_new d
full outer join (select distinct channel_id as channel_id  from fct_order) f
    on d.channel_id =f.channel_id;

-- Checking divisions
-- All divisions exists in data
select d.*, f.division_id as fact_division_id from dim_division_new d
full outer join (select distinct division_id as division_id  from fct_order) f
    on d.division_id =f.division_id;

-- Checking markets
-- it seems there are some old IDs for Europe and NAM that are not used anymore or not in the fact data
select d.*, f.market_id as fact_market_id from dim_market_new d
full outer join (select distinct market_id as market_id from fct_order) f
    on d.market_id=f.market_id;

-- Checking submarkets/country
-- it seems that countryid should be renamed to submarket_id, some ids do not exist in fact data
select d.*, f.country_id as fact_country_id from dim_submarket_new d
full outer join (select distinct country_id as country_id from fct_order) f
    on d.submarket_id =f.country_id;


-- Checking demand_type and supply_type
-- I am focusing on sales orders. But forecast values should be corrected (Forecasts -> Forecast)
select distinct demand_type, supply_type from fct_order
order by 1,2;

-- Checking min and max dates
-- Some of them should be corrected to nulls so the calculations are correct (min dates). It is also interesting that
-- some max dates are very long ahead in time (e.g. 2027-10 vs extraction date of 2025).
select min(purchase_order_requested_date) as min_purchase_order_requested_date,
       min(requested_date_from_customer) as min_requested_date_from_customer,
       min(planned_arrival_date_at_warehouse) as min_planned_arrival_date_at_warehouse,
       min(material_availability_date_at_warehouse) as min_material_availability_date_at_warehouse,
       min(confirmed_date_to_customer) as min_confirmed_date_to_customer,
       max(purchase_order_requested_date) as max_purchase_order_requested_date,
       max(requested_date_from_customer) as max_requested_date_from_customer,
       max(planned_arrival_date_at_warehouse) as max_planned_arrival_date_at_warehouse,
       max(material_availability_date_at_warehouse) as max_material_availability_date_at_warehouse,
       max(confirmed_date_to_customer) as max_confirmed_date_to_customer
from fct_order;

-- checking some different types of supply_type
WITH filtered_ids AS (
    SELECT order_id, market_id, submarket_id, channel_id, article_id, division_id
    FROM fct_order_new
    GROUP BY order_id, market_id, submarket_id, channel_id, article_id, division_id
    HAVING COUNT(DISTINCT supply_type) > 1
)
-- checking one of orders
select * from fct_order_new
where order_id = '02070570' and submarket_id = 'XW34';
-- checking the 'no supply' data
select * from fct_order_new
where supply_type = 'NO SUPPLY';
-- There are no null material_availability_date_at_warehouse values, so the must be assigned somehow by system:
-- e.g. forecasted system availability date, calculated from some passive stock (maybe theoretical availability, returns, or overstock from another order)
-- or by calculation engine by some constraints
-- but not backed by actual supply.

select * from fct_order_new
where supply_type = 'IN TRANSIT';





------------- Projected On Time Availability -------------
-- this metric is used to measure if the product was available in stock to fulfill the order by the time it was requested by the customer

-- calculating here to have a general info on the total level what is the % of that KPI
-- KPI calculated in Power BI model as a measure to enable flexible drill down of that value across different hierarchies

--- interpretation:  On-Time Availability rate =  94.0% — meaning that 94% of the order lines had material available at the warehouse on or before the customer's requested date.

select
    count(*) as total_orders,
    sum(case
            when material_availability_date_at_warehouse <= requested_date_from_customer
                 and material_availability_date_at_warehouse is not null
                 and requested_date_from_customer is not null
                 and supply_type != 'NO SUPPLY'
            then 1
            else 0
        end) as on_time_available_orders,
    cast(sum(case
                when material_availability_date_at_warehouse <= requested_date_from_customer
                     and material_availability_date_at_warehouse is not null
                     and requested_date_from_customer is not null
                     and supply_type != 'NO SUPPLY'
                then 1
                else 0
             end) * 100.0 / count(*) as decimal(5,2)) as on_time_availability_percentage
from fct_order_new;


select
    division_id,
    count(*) as total_orders,
    sum(case
            when material_availability_date_at_warehouse <= requested_date_from_customer
                 and material_availability_date_at_warehouse is not null
                 and requested_date_from_customer is not null
                 and supply_type != 'NO SUPPLY'

            then 1
            else 0
        end) as on_time_available_orders,
    cast(sum(case
                when material_availability_date_at_warehouse <= requested_date_from_customer
                     and material_availability_date_at_warehouse is not null
                     and requested_date_from_customer is not null
                     and supply_type != 'NO SUPPLY'
                then 1
                else 0
             end) * 100.0 / count(*) as decimal(5,2)) as on_time_availability_percentage
from fct_order_new
where demand_type = 'SALES ORDER'
group by division_id





------------- Point 3: Recommendations -----------
------------- Projected On Time Delivery -------------
-- this metric is used to measure the success of a company's delivery process

--- On Time Delivery -- Customer Perspective
select
    count(
        case
            when confirmed_date_to_customer <= requested_date_from_customer then 1
            end) * 100.0 / COUNT(*) as Projected_On_Time_Availability_Customer
from fct_order_new
where demand_type = 'SALES ORDER' and requested_date_from_customer is not null and confirmed_date_to_customer is not null




