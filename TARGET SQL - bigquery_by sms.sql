--                                               Business Case: Target SQL:

##1) Import the dataset and do usual exploratory analysis steps like checking the structure & characteristics of the dataset:
#1.1) Data type of all columns in the "customers" table:
SELECT column_name, data_type
FROM `businesscase-target-sql.Ecommerce.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'customers'

#1.2)Get the time range between which the orders were placed.
SELECT MIN(order_purchase_timestamp) AS first_date,
       MAX(order_purchase_timestamp) AS final_date
FROM `Ecommerce.orders`

#1.3)Count the Cities & States of "customers who ordered" during the given period.
SELECT COUNT(DISTINCT geolocation_city) AS No_of_city,
       COUNT(DISTINCT geolocation_state) AS No_of_state
FROM `Ecommerce.geolocation`

SELECT COUNT(DISTINCT C.customer_city) AS No_of_City, 
       COUNT(DISTINCT C.customer_state) AS No_of_State
FROM `Ecommerce.customers` C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id


##2) In-depth Exploration:
#2.11)Is there a growing trend in the no.of orders placed over the past years?
SELECT EXTRACT(YEAR FROM order_purchase_timestamp) AS Year,
       EXTRACT(MONTH FROM order_purchase_timestamp) AS Month,
       COUNT(order_id) AS orders_per_month
FROM `Ecommerce.orders`
GROUP BY 1,2
ORDER BY 1,2

#2.2)Can we see some kind of monthly seasonality in terms of the no. of orders being placed?
SELECT *, DENSE_RANK() OVER(ORDER BY orders_per_month DESC) AS rank
FROM
(SELECT EXTRACT(MONTH FROM order_purchase_timestamp) AS Month,
        COUNT(DISTINCT order_id) AS orders_per_month
FROM `Ecommerce.orders`
GROUP BY 1) T
ORDER BY rank

#2.3)During what time of the day, do the Brazilian customers mostly place their orders? (Dawn, Morning, Afternoon or Night)
   # 0-6 hrs : Dawn
   # 7-12 hrs : Mornings
   # 13-18 hrs : Afternoon
   # 19-23 hrs : Night
WITH CTE AS
(SELECT Hours, CASE 
       WHEN Hours BETWEEN 0 AND 6 THEN 'Dawn: 0-6 hrs' 
       WHEN Hours BETWEEN 7 AND 12 THEN 'Mornings: 7-12 hrs'
       WHEN Hours BETWEEN 13 AND 18 THEN 'Afternoon: 13-18 hrs'
       WHEN Hours BETWEEN 19 AND 23 THEN 'Night: 19-23 hrs' END AS Hours_Range,
       No_of_orders
FROM
(SELECT EXTRACT(HOUR FROM order_purchase_timestamp) AS Hours,
        COUNT(order_id) AS No_of_orders
FROM `Ecommerce.orders`
GROUP BY 1
ORDER BY 1) T)
SELECT Hours_Range,SUM(No_of_orders) AS Total_Orders
FROM CTE
GROUP BY Hours_Range
ORDER BY 2 DESC


##3)Evolution of E-commerce orders in the Brazil region:
#3.1)Get the month on month no. of orders placed in each state.
SELECT EXTRACT(YEAR FROM O.order_purchase_timestamp) AS Year,
       EXTRACT(MONTH FROM O.order_purchase_timestamp) AS Month,
       C.customer_state,
       COUNT(O.order_id) AS Total_Orders
FROM `Ecommerce.customers` C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id
GROUP BY 1,2,3
ORDER BY 1,2
 
#3.2)How are the customers distributed across all the states?
SELECT customer_state,
       COUNT(customer_unique_id) AS customer_count
FROM `Ecommerce.customers` C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id
GROUP BY 1
ORDER BY 2 DESC
--(OR)
SELECT customer_state,
       COUNT(customer_unique_id) AS customer_count
FROM `Ecommerce.customers`
GROUP BY 1
ORDER BY 2 DESC


##4)Impact on Economy: Analyze the money movement by e-commerce by looking at order prices, freight and others.
#4.1) Get the % increase in the cost of orders from year 2017 to 2018 (include months between Jan to Aug only).You can use the "payment_value" column in the payments table to get the cost of orders.
SELECT *,
       ROUND(((T1.Payment_value_2018-T1.Payment_value_2017)/T1.Payment_value_2018)*100,2) AS Percentage_increase
FROM
(WITH CTE AS
(SELECT Year, Month, payment_value_2017
FROM 
(SELECT EXTRACT(YEAR FROM o.order_purchase_timestamp) AS Year,
        EXTRACT(MONTH FROM o.order_purchase_timestamp) AS Month,
        ROUND(SUM(p.payment_value),2) AS Payment_value_2017                                                         
FROM `Ecommerce.orders` o
INNER JOIN `Ecommerce.payments` p
ON o.order_id = p.order_id
GROUP BY 1,2
ORDER BY 1,2) T
WHERE (Year = 2017 AND Month BETWEEN 1 AND 8) OR (Year = 2018 AND Month BETWEEN 1 AND 8)
ORDER BY Year, Month)
SELECT 
       Month, Payment_value_2017,
       LEAD(Payment_value_2017,8) OVER(ORDER BY Year, Month) AS Payment_value_2018,
FROM CTE
ORDER BY Year,Month
LIMIT 8) T1

#4.2) Calculate the Total & Average value of order price for each state
SELECT C.customer_state,
       ROUND(SUM(OI.price),2) AS Total_Order_Value,
       ROUND(AVG(OI.price),2) AS Avg_Order_Value
FROM `Ecommerce.customers` C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id
INNER JOIN `Ecommerce.order_items` OI
ON O.order_id = OI.order_id
GROUP BY C.customer_state
ORDER BY Total_Order_Value DESC

#4.3) Calculate the Total & Average value of order freight for each state.
SELECT C.customer_state,
       ROUND(SUM(OI.freight_value),2) AS Total_freight,
       ROUND(AVG(OI.freight_value),2) AS Avg_freight
FROM `Ecommerce.customers` C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id
INNER JOIN `Ecommerce.order_items` OI
ON O.order_id = OI.order_id
GROUP BY C.customer_state
ORDER BY Total_freight DESC


##5)Analysis based on sales, freight and delivery time.
#5.1) Find the no. of days taken to deliver each order from the order’s purchase date as delivery time.Also, calculate the difference (in days) between the estimated & actual delivery date of an order.Do this in a single query.
 # You can calculate the delivery time and the difference between the estimated & actual delivery date using the given formula:  
       # time_to_deliver = order_delivered_customer_date - order_purchase_timestamp, 
       # diff_estimated_delivery = order_estimated_delivery_date - order_delivered_customer_date
SELECT order_id,
       DATETIME_DIFF(order_delivered_customer_date,order_purchase_timestamp, DAY) AS time_to_deliver,
       DATETIME_DIFF(order_estimated_delivery_date, order_delivered_customer_date, DAY) AS diff_estimated_delivery
FROM `Ecommerce.orders`
WHERE order_delivered_customer_date IS NOT NULL

#5.2) Find out the top 5 states with the highest & lowest average freight value.
#)Top 5 states with Highest average freight value.
SELECT C.customer_state,
       ROUND(AVG(OI.freight_value),2) AS Avg_freight,
FROM `Ecommerce.customers` C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id
INNER JOIN `Ecommerce.order_items` OI
ON O.order_id = OI.order_id
GROUP BY C.customer_state
ORDER BY Avg_freight DESC
LIMIT 5

#)Top 5 states with  Lowest average freight value.
SELECT C.customer_state,
       ROUND(AVG(OI.freight_value),2) AS Avg_freight,
FROM `Ecommerce.customers` C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id
INNER JOIN `Ecommerce.order_items` OI
ON O.order_id = OI.order_id
GROUP BY C.customer_state
ORDER BY Avg_freight
LIMIT 5

#)5.3) Find out the top 5 states with the highest & lowest average delivery time.
# Top 5 states with highest average delivery time:
SELECT C.customer_state,
       ROUND(AVG(DATETIME_DIFF(O.order_delivered_customer_date,O.order_purchase_timestamp, DAY)),0) AS avg_delivery_day,
FROM `Ecommerce.customers`C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id
WHERE O.order_delivered_customer_date IS NOT NULL
GROUP BY C.customer_state
ORDER BY avg_delivery_day DESC
LIMIT 5

# Top 5 states with lowest average delivery time:
SELECT C.customer_state,
       ROUND(AVG(DATETIME_DIFF(O.order_delivered_customer_date,O.order_purchase_timestamp, DAY)),0) AS avg_delivery_day,
FROM `Ecommerce.customers`C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id
WHERE O.order_delivered_customer_date IS NOT NULL
GROUP BY C.customer_state
ORDER BY avg_delivery_day, customer_state
LIMIT 5

#5.4) Find out the top 5 states where the order delivery is really fast as compared to the estimated date of delivery. You can use the difference between the averages of actual & estimated delivery date to figure out how fast the delivery was for each state.
SELECT C.customer_state,
       ROUND(AVG(DATETIME_DIFF(order_estimated_delivery_date, order_delivered_customer_date, DAY)),0) AS Avg_fast_delivery
FROM `Ecommerce.customers`C
INNER JOIN `Ecommerce.orders`O
ON C.customer_id = O.customer_id
WHERE O.order_delivered_customer_date IS NOT NULL
GROUP BY C.customer_state
ORDER BY Avg_fast_delivery DESC
LIMIT 5


##6)Analysis based on the payments:
#6.1)Find the month on month no. of orders placed using different payment types.
SELECT EXTRACT(YEAR FROM O.order_purchase_timestamp) AS Year,
       EXTRACT(MONTH FROM O.order_purchase_timestamp) AS Month,
       P.payment_type,
       COUNT(O.order_id) AS No_of_orders
FROM `Ecommerce.orders` O
INNER JOIN `Ecommerce.payments` P
ON O.order_id = P.order_id
GROUP BY 1,2,3
ORDER BY 1,2,4 DESC

#6.2)Find the no. of orders placed on the basis of the payment installments that have been paid
SELECT payment_installments, COUNT(order_id) No_of_orders, 
       ROUND(SUM(payment_value),2) AS Total_paymants
FROM `Ecommerce.payments`
GROUP BY payment_installments
ORDER BY No_of_orders DESC

































