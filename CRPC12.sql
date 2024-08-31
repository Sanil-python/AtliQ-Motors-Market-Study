select * from dim_date

select * from electric_vehicle_sales_by_makers

select * from electric_vehicle_sales_by_state

-- 1. List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in 
-- terms of the number of 2-wheelers sold.
with top3 as
(select top 3 m.maker, sum(m.electric_vehicles_sold) as no_of_sold
from electric_vehicle_sales_by_makers m join dim_date d
on m.date = d.date
where d.fiscal_year in(2023, 2024) and m.vehicle_category = '2-Wheelers'
group by m.maker
order by no_of_sold desc),
bottom3 as
(select top 3 m.maker, sum(m.electric_vehicles_sold) as no_of_sold
from electric_vehicle_sales_by_makers m join dim_date d
on m.date = d.date
where d.fiscal_year in(2023, 2024) and m.vehicle_category = '2-Wheelers'
group by m.maker
order by no_of_sold asc)
select * from top3
union all
select * from bottom3

-- 2. Identify the top 5 states with the highest penetration rate in 2-wheeler 
-- and 4-wheeler EV sales in FY 2024.
select top 5 s.state, 
	 round((cast(sum(s.electric_vehicles_sold) as float) / sum(s.total_vehicles_sold)) * 100, 2) as penetration_rate
from electric_vehicle_sales_by_state s join dim_date d
on s.date = d.date
where d.fiscal_year = 2024
group by state
order by penetration_rate desc

-- 3. List the states with negative penetration (decline) in EV sales from 2022 to 2024?
with PenetrationRates as (
    select 
        s.state, 
        d.fiscal_year,
        (cast(sum(s.electric_vehicles_sold) as float) / sum(s.total_vehicles_sold)) * 100 as penetration_rate
    from electric_vehicle_sales_by_state s 
    join dim_date d on s.date = d.date
    where d.fiscal_year in (2022, 2024)
    group by s.state, d.fiscal_year
),
PenetrationComparison as (
    select 
        pr2022.state,
        pr2022.penetration_rate as penetration_rate_2022,
        pr2024.penetration_rate as penetration_rate_2024
    from PenetrationRates pr2022
    join PenetrationRates pr2024 
    on pr2022.state = pr2024.state 
    and pr2022.fiscal_year = 2022 
    and pr2024.fiscal_year = 2024
)
select 
    state, 
    penetration_rate_2022, 
    penetration_rate_2024
from PenetrationComparison
where penetration_rate_2024 < penetration_rate_2022;

-- 4. What are the quarterly trends based on sales volume for the top 5 EV 
-- makers (4-wheelers) from 2022 to 2024?
with cte1 as
(select top 5 maker, sum(electric_vehicles_sold) as total_ev_sold
from electric_vehicle_sales_by_makers m join dim_date d
on m.date = d.date
where vehicle_category = '4-Wheelers' and d.fiscal_year in (2022, 2023, 2024)
group by maker
order by total_ev_sold desc),
cte2 as
(select maker, fiscal_year, quarter, sum(electric_vehicles_sold) as quarterly_sales
from electric_vehicle_sales_by_makers m join dim_date d
on m.date = d.date
where vehicle_category = '4-Wheelers' and fiscal_year in (2022, 2023, 2024)
group by maker, fiscal_year, quarter)
select maker, fiscal_year, quarter, quarterly_sales
from cte2
order by maker, fiscal_year, quarter

-- 5. How do the EV sales and penetration rates in Delhi compare to Karnataka for 2024?
with delhi as (
select state, sum(electric_vehicles_sold) as total_ev_sold, 
	round((cast(sum(s.electric_vehicles_sold) as float) / sum(s.total_vehicles_sold)) * 100, 2) as penetration_rate 
from electric_vehicle_sales_by_state s join dim_date d
on s.date = d.date
where state = 'Delhi' and fiscal_year = 2024
group by state),
karnataka as (
select state, sum(electric_vehicles_sold) as total_ev_sold, 
	round((cast(sum(s.electric_vehicles_sold) as float) / sum(s.total_vehicles_sold)) * 100, 2) as penetration_rate 
from electric_vehicle_sales_by_state s join dim_date d
on s.date = d.date
where state = 'Karnataka' and fiscal_year = 2024
group by state)
select * from delhi
union all
select * from karnataka

-- 6. List down the compounded annual growth rate (CAGR) in 4-wheeler 
-- units for the top 5 makers from 2022 to 2024.
with TopMakers as (
    select top 5 
        maker,
        sum(electric_vehicles_sold) as total_sales
    from electric_vehicle_sales_by_makers
    where vehicle_category = '4-Wheelers'
    group by maker
    order by total_sales desc
),
SalesByYear as (
    select 
        m.maker,
        d.fiscal_year,
        sum(m.electric_vehicles_sold) as total_sales
    from electric_vehicle_sales_by_makers m
    join dim_date d on m.date = d.date
    where d.fiscal_year IN (2022, 2024)
    and m.vehicle_category = '4-Wheelers'
    and m.maker IN (select maker from TopMakers)
    group by m.maker, d.fiscal_year
),
CAGR_Calculation as (
    select 
        s2022.maker,
        s2022.total_sales as sales_2022,
        s2024.total_sales as sales_2024,
        power(cast(s2024.total_sales as float) / s2022.total_sales, 0.5) - 1 as CAGR
    from SalesByYear s2022
    join SalesByYear s2024 
    on s2022.maker = s2024.maker
    and s2022.fiscal_year = 2022
    and s2024.fiscal_year = 2024
)
select 
    maker,
    sales_2022,
    sales_2024,
    round(CAGR * 100, 2) as CAGR_Percentage
from CAGR_Calculation
order by CAGR_Percentage desc;

-- 7. List down the top 10 states that had the highest compounded annual 
-- growth rate (CAGR) from 2022 to 2024 in total vehicles sold.
with top10state as (
select top 10 state, sum(total_vehicles_sold) as total_vehicles_sold
from electric_vehicle_sales_by_state
group by state
order by total_vehicles_sold desc),
salesbyyear as (
select state, fiscal_year, sum(total_vehicles_sold) as total_vehicles_sold
from electric_vehicle_sales_by_state s join dim_date d
on s.date = d.date
where fiscal_year in (2022, 2024) and state in (select state from top10state)
group by state, fiscal_year),
cagr_cal as (
select s2022.state as state, 
	s2022.total_vehicles_sold as sales_2022, 
	s2024.total_vehicles_sold as sales_2024,
	power(cast(s2024.total_vehicles_sold as float) / s2022.total_vehicles_sold, 0.5) - 1 as cagr
from salesbyyear s2022 join salesbyyear s2024
on s2022.state = s2024.state
and s2022.fiscal_year = 2022 
and s2024.fiscal_year = 2024)
select state, sales_2022, sales_2024, round((cagr * 100), 2) as cagr_percent
from cagr_cal
order by cagr_percent desc

-- 8. What are the peak and low season months for EV sales based on the data from 2022 to 2024?
select datename(month, cast(s.date as date)) as month_name, sum(electric_vehicles_sold) as total_ev_sold
from electric_vehicle_sales_by_state s join dim_date d
on s.date = d.date
group by datename(month, cast(s.date as date))
order by total_ev_sold desc

-- 9. What is the projected number of EV sales (including 2-wheelers and 4-wheelers) for the top 10 states
-- by penetration rate in 2030, based on the compounded annual growth rate (CAGR) from previous years?
with TopStatesByPenetration as (
    select top 10
        s.state,
        (sum(s.electric_vehicles_sold) * 1.0 / sum(s.total_vehicles_sold)) * 100 as penetration_rate
    from electric_vehicle_sales_by_state s
    join dim_date d on s.date = d.date
    where d.fiscal_year in (2022, 2023, 2024)
    group by s.state
    order by penetration_rate desc
),
SalesByYear as (
    select 
        s.state,
        d.fiscal_year,
        sum(s.electric_vehicles_sold) as total_sales
    from electric_vehicle_sales_by_state s
    join dim_date d on s.date = d.date
    where d.fiscal_year in (2022, 2024)
    and s.state in (select state from TopStatesByPenetration)
    group by s.state, d.fiscal_year
),
CAGR_Calculation as (
    select 
        s2022.state,
        s2022.total_sales as sales_2022,
        s2024.total_sales as sales_2024,
        power(cast(s2024.total_sales as float) / s2022.total_sales, 1.0 / 2) - 1 as CAGR
    from SalesByYear s2022
    join SalesByYear s2024 
    on s2022.state = s2024.state
    and s2022.fiscal_year = 2022
    and s2024.fiscal_year = 2024
),
ProjectedSales as (
    select 
        state,
        sales_2024 as latest_sales,
        CAGR,
        round(sales_2024 * power(1 + CAGR, 6), 0) as projected_sales_2030
    from CAGR_Calculation
)
select 
    state,
    latest_sales as sales_2024,
    round(CAGR * 100, 2) as CAGR_Percentage,
    projected_sales_2030
from ProjectedSales
order by projected_sales_2030 desc;

-- 10. Estimate the revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2022 vs 2024 and 2023 vs 2024, 
-- assuming an average unit price for 2-Wheelers category as 85,000 and for 4_wheelers category as 15,00,000.
with RevenueCalculation as (
    select
        d.fiscal_year,
        sum(cast(case 
            when m.vehicle_category = '2-Wheelers' then cast(m.electric_vehicles_sold as bigint) * 85000 
            when m.vehicle_category = '4-Wheelers' then cast(m.electric_vehicles_sold as bigint) * 1500000 
            else 0 
        end as bigint)) as total_revenue
    from electric_vehicle_sales_by_makers m
    join dim_date d on m.date = d.date
    group by d.fiscal_year
),
GrowthRates as (
    select
        '2022 vs 2024' as comparison_period,
        round((cast(rc2024.total_revenue as decimal(18, 2)) - cast(rc2022.total_revenue as decimal(18, 2))) * 100.0 / cast(rc2022.total_revenue as decimal(18, 2)), 2) as revenue_growth_rate
    from RevenueCalculation rc2024
    join RevenueCalculation rc2022 
    on rc2024.fiscal_year = 2024 and rc2022.fiscal_year = 2022
	union all
    select
        '2023 vs 2024' as comparison_period,
        round((cast(rc2024.total_revenue as decimal(18, 2)) - cast(rc2023.total_revenue as decimal(18, 2))) * 100.0 / cast(rc2023.total_revenue as decimal(18, 2)), 2) as revenue_growth_rate
    from RevenueCalculation rc2024
    join RevenueCalculation rc2023 
    on rc2024.fiscal_year = 2024 and rc2023.fiscal_year = 2023
)
select
    comparison_period,
    revenue_growth_rate as "Growth Rate (%)"
from GrowthRates;
