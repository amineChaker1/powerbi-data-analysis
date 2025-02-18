SELECT ReviewID,
CustomerID,
ProductID,
ReviewDate,
Rating, 
REPLACE(ReviewText, '  ',' ') as ReviewText
FROM [MarketingAnalytics].[dbo].[customer_reviews]
