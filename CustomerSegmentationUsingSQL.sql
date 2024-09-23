

create database customerSegmentationAnalysis;

use customerSegmentationAnalysis;

create table customer_segmentation(InvoiceNo varchar(30),
StockCode varchar(10),
description varchar(50),
Quantity int,
InvoiceDate varchar(20),
UnitPrice float(10),
CustomerID varchar(20),
Country varchar(30) );

select * from customer_segmentation;

select count(*) from customer_segmentation;

############## ################1. Data Cleaning and Preprocessing ####################

## a. Convert InvoiceDate to Proper Datetime Format##

-- Add a new column for the converted date if needed
ALTER TABLE customer_segmentation
ADD CONVERTED_InvoiceDate DATETIME;

-- Convert InvoiceDate into a proper datetime format
UPDATE customer_segmentation
SET CONVERTED_InvoiceDate = STR_TO_DATE(InvoiceDate, '%m/%d/%Y %H:%i');
-- Create and populate the temporary table in one step
CREATE TEMPORARY TABLE top20000rows AS
SELECT *
FROM customer_segmentation
ORDER BY CONVERTED_InvoiceDate DESC
LIMIT 20000;

SET SQL_SAFE_UPDATES = 0;
delete from customer_segmentation;
SET SQL_SAFE_UPDATES = 1;

INSERT INTO customer_segmentation SELECT * from top20000rows; 

drop temporary table top20000rows;


####### b. Handle Missing or Null Values #####

select * from customer_segmentation
where CustomerID IS NULL OR CustomerID = '' OR InvoiceDate IS NULL;

delete from customer_segmentation
where CustomerID IS NULL OR CustomerID = '' OR InvoiceDate IS NULL;

########### c. Create a Total Price Column#########

## add selling price column 
ALTER table customer_segmentation
ADD SellingPrice DECIMAL(10, 2) NOT NULL DEFAULT 0; 

UPDATE customer_segmentation
SET SellingPrice = Quantity * UnitPrice;

########################### 2. Customer Segmentation Using RFM Analysis###########################

/* An effective way to segment customers is by performing RFM (Recency, Frequency, Monetary) analysis:

Recency: How recently did the customer make a purchase?
Frequency: How often do they make purchases?
Monetary: How much money have they spent? */


/* a. Calculate Recency
Recency represents the time since the last purchase. You can calculate the number of days since the customer's last invoice using a window function and CTE.
*/

WITH Recency_CTE AS (
    SELECT 
        CustomerID,
        MAX(CONVERTED_InvoiceDate) OVER (PARTITION BY CustomerID) AS LastPurchaseDate,
        DATEDIFF('2024-09-19', MAX(CONVERTED_InvoiceDate) OVER (PARTITION BY CustomerID)) AS Recency
    FROM customer_segmentation
)
-- View the result
SELECT * FROM Recency_CTE;

/* b. Rank Customers Based on Frequency
Now, rank customers based on their frequency using a similar method:  */

WITH Frequency_Rank AS (
    SELECT 
        CustomerID,
        Frequency,
        NTILE(5) OVER (ORDER BY Frequency DESC) AS FrequencyScore  -- 1 is most frequent, 5 is least frequent
    FROM (
        SELECT 
            CustomerID,
            COUNT(DISTINCT InvoiceNo) AS Frequency
        FROM customer_segmentation
        GROUP BY CustomerID
    ) AS FrequencyData
)
-- View the result
SELECT * FROM Frequency_Rank;

/* c. Rank Customers Based on Monetary Value
Finally, rank customers based on their total spending:
*/

WITH Rank_Customer_per_TotalSpent as (
select CustomerID, TotalSpent,
ntile(5) over (order by TotalSpent desc) as TotalSpentMoney -- 1 means the highest spender, 5 means the lowest spender.

from (
select CustomerID, sum(SellingPrice) as TotalSpent
from customer_segmentation 
group by CustomerID) as TotalSpentData
)
select * from Rank_Customer_per_TotalSpent;



################# 1. Most Profitable Countries Using Window Functions   ##########################

select country,
sum(sellingPrice) as TotalRevenue,
rank() over (order by sum(sellingPrice) desc) as RevenueRank
from customer_segmentation
group by country
order by TotalRevenue desc;


############################# 2. Countries with the Most Customers Using Window Functions   ##############################


WITH CustomerCounts AS (
    SELECT 
        Country,
        COUNT(DISTINCT CustomerID) AS TotalCustomers
    FROM customer_segmentation
    GROUP BY Country
)

SELECT 
    Country,
    TotalCustomers,
    RANK() OVER (ORDER BY TotalCustomers DESC) AS CustomerRank
FROM CustomerCounts
ORDER BY TotalCustomers DESC;

########################################

select * from customer_segmentation where SellingPrice = 0.0;

#################Update the table with a new column cancelled Transaction #####################

ALTER table customer_segmentation
add column CancelledTransactions varchar(20);

UPDATE customer_segmentation
SET CancelledTransactions = if(SellingPrice <= 0.0, 'Cancelled', 'NotCancelled');

##################### Analyse the cancelled Orders ############################

SELECT 
    Country, 
    count(CancelledTransactions) AS CancellationCount
    from customer_segmentation
    group by Country 
    order by 2 desc;

-- Ans: UK shows most people return their orders and also shows people engagement here.alter

## Let's try to find the stock which has been cancelled or retuned the most

select StockCode, description,
count(CancelledTransactions) AS CancellationCount
from customer_segmentation
group by StockCode, description
order by 3 desc
limit 10;






select * from customer_segmentation;
