
/*
======================================================
Project: Amazon (Northwind) Sales Analysis - End-to-End
BY: Mariam Helal
Tools: SQL Server, Power BI
Description: Comprehensive analysis covering KPIs, Logistics, 
             Product Performance, and Employee Efficiency.
======================================================
*/

USE [Amazon_Sales_DB];
GO

-- SECTION 1: HIGH-LEVEL EXECUTIVE KPIs (Slide 1)
------------------------------------------------------
-- This query calculates the core business metrics
SELECT 
    -- Total Revenue: Calculated with TRY_CAST to prevent conversion errors
    ROUND(SUM(TRY_CAST([UnitPrice] AS FLOAT) * TRY_CAST([Quantity] AS INT)), 2) AS Total_Revenue, 
    
    -- Total Orders: Distinct count of unique orders
    COUNT(DISTINCT [OrderID]) AS Total_Orders, 
    
    -- Total Quantity: Combined sum of all units sold
    SUM(TRY_CAST(ISNULL([Quantity], 0) AS INT)) AS Total_Quantity 
FROM [dbo].[Order Details];
GO


-- SECTION 2: PRODUCT PERFORMANCE & PARETO ANALYSIS (Slide 2)
------------------------------------------------------
-- Identifies products contributing to 80% of total revenue
WITH ProductSales AS (
    SELECT 
        P.[ProductName], 
        SUM(TRY_CAST(OD.[UnitPrice] AS FLOAT) * TRY_CAST(OD.[Quantity] AS INT)) AS RevenuePerProduct,
        SUM(SUM(TRY_CAST(OD.[UnitPrice] AS FLOAT) * TRY_CAST(OD.[Quantity] AS INT))) OVER() AS Grand_Total
    FROM [dbo].[Order Details] OD
    JOIN [dbo].[Products] P ON OD.[ProductID] = P.[ProductID]
    GROUP BY P.[ProductName]
),
CumulativeSales AS (
    SELECT *,
        SUM(RevenuePerProduct) OVER(ORDER BY RevenuePerProduct DESC) / Grand_Total AS Running_Pct
    FROM ProductSales
)
SELECT 
    [ProductName], 
    ROUND(RevenuePerProduct, 2) AS Revenue,
    ROUND(Running_Pct * 100, 2) AS Cumulative_Percentage
FROM CumulativeSales
WHERE Running_Pct <= 0.80 -- The Pareto Rule
ORDER BY Revenue DESC;
GO


-- SECTION 3: SHIPPING & LOGISTICS EFFICIENCY (Slide 3)
------------------------------------------------------
-- Handles NULL ShippedDates and calculates delivery performance
SELECT 
    S.[CompanyName] AS Shipper_Name,
    COUNT(O.[OrderID]) AS NumberOfShipments,
    -- If ShippedDate is NULL, we assume it is still in transit (using GETDATE)
    AVG(DATEDIFF(day, O.[OrderDate], ISNULL(O.[ShippedDate], GETDATE()))) AS Avg_Lead_Time_Days,
    ROUND(SUM(TRY_CAST(ISNULL(O.[Freight], 0) AS FLOAT)), 2) AS Total_Freight_Cost
FROM [dbo].[Orders] O
JOIN [dbo].[Shippers] S ON O.[ShipVia] = S.[ShipperID]
GROUP BY S.[CompanyName];
GO


-- SECTION 4: CATEGORY INSIGHTS & PRICING TIERS 
------------------------------------------------------
-- Analyzes sales distribution by category and price segments
SELECT 
    C.[CategoryName],
    COUNT(DISTINCT P.[ProductID]) AS ProductCount,
    SUM(TRY_CAST(OD.[Quantity] AS INT)) AS UnitsSold,
    CASE 
        WHEN TRY_CAST(OD.[UnitPrice] AS FLOAT) < 50 THEN 'Budget'
        WHEN TRY_CAST(OD.[UnitPrice] AS FLOAT) BETWEEN 50 AND 200 THEN 'Mid-Range'
        ELSE 'Premium'
    END AS Price_Segment
FROM [dbo].[Categories] C
JOIN [dbo].[Products] P ON C.[CategoryID] = P.[CategoryID]
JOIN [dbo].[Order Details] OD ON P.[ProductID] = OD.[ProductID]
GROUP BY C.[CategoryName], 
    CASE 
        WHEN TRY_CAST(OD.[UnitPrice] AS FLOAT) < 50 THEN 'Budget'
        WHEN TRY_CAST(OD.[UnitPrice] AS FLOAT) BETWEEN 50 AND 200 THEN 'Mid-Range'
        ELSE 'Premium'
    END
ORDER BY CategoryName;
GO


-- SECTION 5: EMPLOYEE PERFORMANCE 
------------------------------------------------------
-- Cleaned data for employee sales ranking
SELECT 
    E.[FirstName] + ' ' + E.[LastName] AS Full_Name,
    ISNULL(E.[Title], 'Staff') AS Job_Title,
    COUNT(DISTINCT O.[OrderID]) AS Orders_Processed,
    ROUND(SUM(TRY_CAST(OD.[UnitPrice] AS FLOAT) * TRY_CAST(OD.[Quantity] AS INT)), 2) AS Revenue_Generated
FROM [dbo].[Employees] E
JOIN [dbo].[Orders] O ON E.[EmployeeID] = O.[EmployeeID]
JOIN [dbo].[Order Details] OD ON O.[OrderID] = OD.[OrderID]
GROUP BY E.[FirstName], E.[LastName], E.[Title]
ORDER BY Revenue_Generated DESC;
GO