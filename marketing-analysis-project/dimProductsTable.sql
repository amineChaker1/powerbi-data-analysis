--- Seeing the Products Table
SELECT *
from MarketingAnalytics.dbo.products


-- Categorizing the products based on thier price
-- Didn't choose category because it makes data more redundant
SELECT ProductID, ProductName, Price,
CASE
    WHEN Price < 50 THEN 'Low'
	WHEN Price BETWEEN 50 AND 200 THEN 'Medium'
	ELSE 'High'
END AS PriceCategory
FROM MarketingAnalytics.dbo.products
