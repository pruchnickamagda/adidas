--
--Magda Tuczynska Adidas Case Study 01.04.2025


---------------------------
---------------------------
--dim_channel--
-- cleaning channel ID: null values are not allowed to be in the column which represents
-- unique key column

select
        case when channel_id is null then -1 else channel_id end as channel_id,
        channel_name
into dim_channel_new
from dim_channel


---------------------------
---------------------------
--dim_division--
-- product type
-- no adjustments needed just coping data to have untouched version

select *
into dim_division_new
from dim_division



---------------------------
---------------------------
-- dim_market--
-- check for the markets in fact table since there are duplicated values for NAM and Europe
-- Unique keys should be fixed to include only deduplicated values


-- checking the values in fact to see if we have all markets in order data
-- trying to understand if the problematic markets are in the fact
select distinct t2.market_description,
                count(market_description)
from fct_order_new t1
left join dim_market t2 on t1.market_id=t2.market_id
group by t2.market_description

select distinct t2.market_description,
                t1.market_id,
                count(market_description)
from fct_order_new t1
left join dim_market t2 on t1.market_id=t2.market_id
group by t2.market_description,
         t1.market_id


-- duplicating the raw table --
select *
into dim_market_new
from dim_market


-- cleaning dim_market --
-- combining NAM 1, 2, 3 to be one value since it is represented by the same ID

delete from dim_market_new
where market_id = '65B' and market_description in ('NAM 2', 'NAM 3')

--updating description for NAM 1 to include the removed data
update dim_market_new
set market_description = 'NAM 123'
where market_description = 'NAM 1'

-- updating second Europe to have different description
update dim_market_new
set market_description = 'EUROPE OTHER'
where market_id = '2C' ;


-- adding general_market_description column to be able to combine to main markets
alter table dim_market_new
add general_market_description VARCHAR(50);

update dim_market_new
set general_market_description =
    case
        when market_description = 'NAM 123' then 'NAM'
        when market_description = 'NAM' then 'NAM'
        when market_description = 'EUROPE' then 'EMEA'
        when market_description = 'EUROPE OTHER' then 'EMEA'
        when market_description = 'EMERGING MARKETS' then 'EM'
        when market_description = 'LATAM' then 'LATAM'
        when market_description = 'JAPAN' then 'APAC'
        else 'OTHER'
    end;



---------------------------
---------------------------
-- dim_submarket--
select *
into dim_submarket_new
from dim_submarket

-- normalizing values to be the same style for better readability
update dim_submarket_new
set submarket_description = UPPER(submarket_description);

-- adding columns representing general_markets
alter table dim_submarket_new
add general_market_description VARCHAR(50);


update dim_submarket_new
set general_market_description =
    case
        when submarket_description like 'EU%' then 'EMEA'
        when submarket_description in ('NORTH AMERICA', 'CANADA') then 'NAM'
        when submarket_description in ('ARGENTINA', 'REST OF LATAM') then 'LATAM'
        when submarket_description = 'JAPAN' then 'APAC'
        when submarket_description = 'DUBAI' then 'EMEA'
        else 'OTHER'
    end;

---------------------------
---------------------------
-- fact table
select *
into fct_order_new
from fct_order;

----- renaming country id to submarket_id after noticing country_id represents submarkets
exec sp_rename 'fct_order_new.country_id', 'submarket_id', 'COLUMN';

----- clean date columns by replacing strange date to null
update fct_order_new
set
    purchase_order_requested_date             = case when purchase_order_requested_date = '1900-01-01' then null else  purchase_order_requested_date end,
    planned_arrival_date_at_warehouse         = case when planned_arrival_date_at_warehouse   = '1900-01-01' then null else planned_arrival_date_at_warehouse end,
    material_availability_date_at_warehouse   = case when material_availability_date_at_warehouse = '1900-01-01' then null else material_availability_date_at_warehouse end,
    requested_date_from_customer              = case when requested_date_from_customer = '1900-01-01' then null else  requested_date_from_customer end,
    confirmed_date_to_customer                = case when confirmed_date_to_customer = '1900-01-01' then null else  confirmed_date_to_customer end
where
    purchase_order_requested_date            = '1900-01-01'
 or planned_arrival_date_at_warehouse        = '1900-01-01'
 or material_availability_date_at_warehouse  = '1900-01-01'
 or requested_date_from_customer             = '1900-01-01'
 or confirmed_date_to_customer               = '1900-01-01';

----- aligning values in the demand type since there are two versions for forecast value: forecast and forecasts
update fct_order_new
set demand_type = 'FORECAST'
where demand_type = 'FORECASTS' ;


----- adding a column which indicates
alter table fct_order_new
add customer_delivery_delay_days as datediff(day, requested_date_from_customer, confirmed_date_to_customer);


-- adding delivery status for warehouse and customer
alter table fct_order_new
add customer_delivery_status VARCHAR(50),
    warehouse_delivery_status VARCHAR(50);


update fct_order_new
set customer_delivery_status =
    case
        when confirmed_date_to_customer <= requested_date_from_customer  then 'On Time' else 'Delayed'
    end,
    warehouse_delivery_status =
    case
        when planned_arrival_date_at_warehouse <= material_availability_date_at_warehouse then 'On Time' else 'Delayed'
    end;