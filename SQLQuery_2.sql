Create Database project_2
Use project_2

Create Table Retail_store (
    Customer_Reference_ID INT,
    Item_Purchased varchar(15),
    Purchase_amount float,
    Date_Purchase Date,
    Review_rating float,
    Payment_method Varchar(15)

)

Select * from Retail_store

set dateformat dmy

Bulk insert Retail_store 
from  '/var/opt/mssql/Fashion_Retail_Sales 3.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);

--Create a copy 
select * from Retail_store
select * into sales 
from  Retail_store

select * from Retail_store
select * from sales

--Data Cleaning
--step-1: To check for duplicates
select Customer_Reference_ID, count(*)
from sales
group by Customer_Reference_ID
HAVING count(*) >1

--or 

WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY Customer_Reference_ID ORDER BY Customer_Reference_ID) AS ROW_NUM
    FROM sales
)
SELECT * FROM CTE;

--no duplicates 

--to check datatype  
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME= 'sales'


--to check null values

Select * from sales
where  Customer_Reference_ID is null
or 
Item_Purchased is null
OR
Purchase_amount is NULL
OR
Date_Purchase is NULL
or 
Review_rating is NULL
or 
Payment_method is NULL


--treating null values

UPDATE sales
SET Review_Rating = (
    SELECT AVG(Review_Rating)
    FROM sales
    WHERE Review_Rating IS NOT NULL
)
WHERE Review_Rating IS NULL;

UPDATE sales
SET Purchase_Amount = (
    SELECT AVG(Purchase_Amount)
    FROM sales
    WHERE Purchase_Amount IS NOT NULL
)
WHERE Purchase_Amount IS NULL;

Update sales
Set Review_rating=(
    Select Round((Review_Rating),1))
    from sales

Update sales
Set Purchase_amount=(
    Select Round((Purchase_amount),0))
    from sales

select * from sales

select distinct Payment_method
from sales

--To clean inconsistency data

SELECT DISTINCT 
  Payment_method AS original_status,
  TRIM(REPLACE(REPLACE(Payment_method, CHAR(13), ''), CHAR(10), '')) AS cleaned_status
FROM sales;

UPDATE sales
SET Payment_method = TRIM(REPLACE(REPLACE(Payment_method, CHAR(13), ''), CHAR(10), ''));

SELECT DISTINCT Payment_method FROM sales;


--Data anlaysis

--1. Which item categories have the highest and lowest total sales revenue?
select * from sales
select top 5 Item_Purchased,
    SUM(Purchase_amount) As revenue
from sales
group by Item_Purchased
order by revenue DESC 

select top 5 Item_Purchased,
    SUM(Purchase_amount) As revenue
from sales
group by Item_Purchased
Order by revenue ASC


-- → Helps identify profitable vs. weak categories.

--2. What is the average purchase amount per transaction, and how does it vary across categories?

select * from sales
select Distinct Item_Purchased, avg(Purchase_amount) As avg_amount
from sales
Group by Item_Purchased
order by avg_amount DESC 




WITH CategoryAvg AS (
    SELECT 
        Item_Purchased,
        AVG(Purchase_Amount) AS Category_Avg
    FROM sales
    GROUP BY Item_Purchased
),
OverallAvg AS (
    SELECT 
        AVG(Purchase_Amount) AS Overall_Avg
    FROM sales
)
SELECT 
    c.Item_Purchased,
    c.Category_Avg,
    o.Overall_Avg,
    c.Category_Avg - o.Overall_Avg AS Difference_From_Overall
FROM CategoryAvg c
CROSS JOIN OverallAvg o
ORDER BY Difference_From_Overall DESC;


  -- → Helps understand spending behavior by category.

--3. Which payment methods are most and least used by customers?
select payment_method,count(*) as count_payment
from sales
group by Payment_method


  -- → Supports decision-making on which payment options to promote or retire.

--4. What is the distribution of review ratings across item categories?
select top 10 Item_Purchased,
  case 
    when (Review_rating) BETWEEN 1 and 2 then  '1-2'
    when (Review_rating) BETWEEN 2 and 3 then  '2-3'
    when (Review_rating) BETWEEN 3 and 4 then  '3-4'
    when (Review_rating) BETWEEN 4 and 5 then  '4-5'
  end as Review_rating,
  count(*) as rating_count
from sales 
group by Item_Purchased,
   case 
    when (Review_rating) BETWEEN 1 and 2 then  '1-2'
    when (Review_rating) BETWEEN 2 and 3 then  '2-3'
    when (Review_rating) BETWEEN 3 and 4 then  '3-4'
    when (Review_rating) BETWEEN 4 and 5 then  '4-5'
  end 
Having
  case 
    when (Review_rating) BETWEEN 1 and 2 then  '1-2'
    when (Review_rating) BETWEEN 2 and 3 then  '2-3'
    when (Review_rating) BETWEEN 3 and 4 then  '3-4'
    when (Review_rating) BETWEEN 4 and 5 then  '4-5'
  end = '4-5'
Order by rating_count  DESC

-- → Highlights customer satisfaction and product quality concerns.

--5. Who are the top 10 customers by total spend, and how frequently do they purchase?
select * from sales

SELECT TOP 10 
  Customer_Reference_ID,
  COUNT(*) AS purchase_count,         -- number of transactions
  SUM(Purchase_amount) AS total_spend          -- total money spent
FROM 
  sales
GROUP BY 
  Customer_Reference_ID
ORDER BY 
  total_spend DESC;


  -- → Identifies high-value customers for loyalty campaigns.

--6. Is there a correlation between review ratings and total purchase amount per customer?

WITH customer_summary AS (
  SELECT 
    Customer_Reference_ID,
    AVG(CAST(Review_rating AS FLOAT)) AS avg_rating,
    SUM(CAST(Purchase_amount AS FLOAT)) AS total_spend
  FROM 
    sales
  GROUP BY 
    Customer_Reference_ID
),
stats AS (
  SELECT 
    COUNT(*) AS n,
    SUM(avg_rating) AS sum_x,
    SUM(total_spend) AS sum_y,
    SUM(avg_rating * total_spend) AS sum_xy,
    SUM(POWER(avg_rating, 2)) AS sum_x2,
    SUM(POWER(total_spend, 2)) AS sum_y2
  FROM 
    customer_summary
)
SELECT 
  (n * sum_xy - sum_x * sum_y) /
  SQRT((n * sum_x2 - POWER(sum_x, 2)) * (n * sum_y2 - POWER(sum_y, 2))) 
  AS correlation_coefficient
FROM stats;


  -- → Investigates whether happier customers spend more.

--7. What is the monthly trend of total sales volume and revenue?
select 
    MONTH(Date_Purchase) As sales_Month,
    sum(Purchase_amount) as revenue     
from sales
group by MONTH(Date_Purchase)
order by MONTH(Date_Purchase),revenue 

  -- → Reveals sales seasonality or the impact of promotions.


--8. How many unique customers buy from multiple categories vs. those who stick to one?

SELECT Customer_Reference_ID,
  CASE
    WHEN COUNT(DISTINCT Item_Purchased) = 1 THEN 'One Category'
    ELSE 'Multiple Categories'
  END AS category_group,
  COUNT(DISTINCT Customer_Reference_ID) AS customer_count
FROM 
  sales
GROUP BY 
  Customer_Reference_ID
ORDER BY 
  category_group;

  -- → Assists in cross-selling strategy.


