//Captures high-level stats of expenses similar to Spend Smart but without vendorname

SET VAR_START_DATE ='01-JAN-2019';
SET VAR_END_DATE = getdate();

with a_cte (expensedate, expenseid,customerid,currencycode,total_amt) as 
((select transactiondate,expensereportlineitemid,customerid,currencycodespent,amountspent from "BRONZE_CR"."CR_C1_PROD_CHROME_EXPENSE"."TBL_EXPENSEREPORTLINEITEM")
 union 
 (select transactiondate,expensereportlineitemid,customerid,currencycodespent,amountspent from "BRONZE_CR"."CR_C2_PROD_CHROME_EXPENSE"."TBL_EXPENSEREPORTLINEITEM")
 union
(select transactiondate,expensereportlineitemid,customerid,currencycodespent,amountspent from "BRONZE_CR"."CR_C7_PROD_CHROME_EXPENSE"."TBL_EXPENSEREPORTLINEITEM")),

b_cte (expenseid,businessunit,customerid,categorygroup) as (select expensereportlineitemid,BU_SHARD_ID,CUSTOMERID,STANDARD_EXPENSE_CATEGORY_GROUP from "SILVER_CR"."CR_PROD"."TBL_STANDARD_EXPENSE_TYPE"),

c_cte (CURRENCYCODETO, CURRENCYCODEFROM, DATEEFF, DATEEND, EXRATE)
as
(select distinct c.CURRENCYCODE as CURRENCYCODETO, cpta.DISBURSEMENTCURRENCYCODE as CURRENCYCODEFROM, cpta.DATEEFFECTIVE as DATEEFF, cpta.DATEEND as DATEEND, cpta.EXCHANGERATETOFIRMCURRENCY AS EXRATE
from "BRONZE_CR"."CR_C1_PROD_CHROME_EXPENSE"."TBL_CURRENCYPTA" cpta
, "BRONZE_CR"."CR_C1_PROD_CHROME_EXPENSE"."TBL_CUSTOMER" c
where cpta.CUSTOMERID = c.CUSTOMERID
and c.CURRENCYCODE = 'USD'
and cpta._FIVETRAN_DELETED = 'FALSE')

select 
year(a_cte.expensedate) as year
, month(a_cte.expensedate) as month
, case when b_cte.categorygroup = 'Air' then 'Flights'
    when b_cte.categorygroup =  'Ground' then 'Ground Transportation/Rentals'
        when b_cte.categorygroup = 'Lodging' then 'Lodging'
            when b_cte.categorygroup = 'Meals' then 'Meals'
               else 'Other' end as Category
, count(*) as expensecount
, sum(case when a_cte.CURRENCYCODE = 'USD' then a_cte.TOTAL_AMT else a_cte.TOTAL_AMT*c_cte.EXRATE end) as USD_AMOUNT

from a_cte
left join b_cte ON b_cte.EXPENSEID = a_cte.EXPENSEID and b_cte.customerid and a_cte.customerid
left join c_cte on c_cte.CURRENCYCODEFROM = a_cte.CURRENCYCODE 
and c_cte.DATEEFF < a_cte.EXPENSEDATE 
and c_cte.DATEEND > a_cte.EXPENSEDATE 
--and b_cte.businessunit = 'CR'

where a_cte.expensedate>= $var_start_date and a_cte.expensedate<= $var_end_date
group by year,month,categorygroup order by year,month,categorygroup