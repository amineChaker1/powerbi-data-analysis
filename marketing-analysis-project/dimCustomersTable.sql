-- joining the customer and geography table to enrich data using a left join
SELECT C.CustomerID,
C.CustomerName,
C.Email,
C.Gender,
C.Age ,
G.Country,
G.City,
G.GeographyID

from MarketingAnalytics.dbo.customers as C
left join MarketingAnalytics.dbo.geography as G on C.GeographyID = G.GeographyID
