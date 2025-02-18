SELECT EngagementID
      ,ContentID
      ,Upper(REPLACE(ContentType, 'SOCIALMEDIA' ,'Social Media')) as ContentType
      ,Likes
      ,FORMAT(CONVERT(DATE,EngagementDate),'dd.MM.yyyy') as EngagementDate
      ,CampaignID
      ,ProductID
      ,PARSENAME(REPLACE(ViewsClicksCombined, '-' , '.') ,2) as Views
	  ,PARSENAME(REPLACE(ViewsClicksCombined, '-' , '.') ,1) as Clicks

  FROM [MarketingAnalytics].[dbo].[engagement_data]