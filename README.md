# Table of contents

- [Objective](#objective)
- [Data Source](#data-source)
- [Development](#development)
  - [Pseudocode](#pseudocode)
  - [Data Exploration](#data-exploration)
  - [Data Cleaning](#data-cleaning)
  - [Transform the Data](#transform-the-data)
- [Enreching](#enreching)
- [Visualization](#visualization)
  - [Results](#results)
  - [DAX Measures](#dax-measures)
- [Analysis](#analysis)
  - [Findings](#findings)
- [Recommendations](#recommendations)
- [Conclusion](#conclusion)

# Objective

- What is the key pain point?

An online retail business, is facing reduced customer engagement and conversion rates despite launching several new online marketing campaigns. They want to conduct a detailed analysis and identify areas for improvement in their marketing strategies.

- What is the ideal solution?

To create a dashboard that provides insights into thier Key Performance Indicators (KPIs) :

- Conversion Rate : Percentage of website visitors who make a purchase.
- Customer Engagement Rate: Level of interaction with marketing content (clicks, likes, comments).
- Average Order Value (AOV): Average amount spent by a customer per transaction.
- Customer Feedback Score: Average rating from customer reviews.

This will help the marketing team make informed decisions about:

- Where their intrested clients fall off in the purchase process ?
- What marketing content have the best returns from the campaign ?
- What are the common themes in customer reviews ?

# Data source

- What data is needed to achieve our objective?

3 Fact tables and 3 Dimension tables

- customer journey table
- customer reviews table
- engagement data table
- customer, product, geography dimension tables

- Where is the data coming from?
  The data is avaiable as an SQL Server database it's the file uploaded that ends with .bak

# Development

## Pseudocode

- What's the general approach in creating this solution from start to finish?

1. Get the data
2. Load the data into SQL Server
3. Explore the data in SQL Server
4. Clean and Enrich the data with SQL
5. Fetch the data from the SQL Server with Python
6. Conduct sentiment analysis with the nltk library
7. Visualize the data in Power BI
8. Generate the findings based on the insights
9. Write the documentation + commentary

## Data exploration notes

1. In the Engagement data table some of the columns in diffrent tables have inconsistent data , And columns that are combined so we need to extract them.
2. In the Customer Journy table we have multiple null values so we have to standardize the data to replace these null values
3. Looking at the Geography table we only need one column so we can combine it with the Customer table and drop all the other columns
4. In the Products dimension table categorizing the price is possible.

## Data cleaning

- What do we expect the clean data to look like? (What should it contain? What contraints should we apply to it?)

The aim is to refine our dataset to ensure it is structured and ready for analysis.

The cleaned data should meet the following criteria and constraints:

- Only relevant columns should be retained.
- All data types should be appropriate for the contents of each column.
- No column should contain null values, indicating complete data for all records.

### Transform the data

```sql
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
```

```sql
-- Outer query selects the final cleaned and standardized data

SELECT
    JourneyID,
    CustomerID,
    ProductID,
    VisitDate,
    Stage,
    Action,
    COALESCE(Duration, avg_duration) AS Duration  -- Replaces missing durations with the average duration for the corresponding date
FROM
    (
        -- Subquery to process and clean the data
        SELECT
            JourneyID,
            CustomerID,
            ProductID,
            VisitDate,
            UPPER(Stage) AS Stage,
            Action,
            Duration,
            AVG(Duration) OVER (PARTITION BY VisitDate) AS avg_duration,  -- Calculates the average duration for each date, using only numeric values
            ROW_NUMBER() OVER (
                PARTITION BY CustomerID, ProductID, VisitDate, UPPER(Stage), Action  -- Groups by these columns to identify duplicate records
                ORDER BY JourneyID  -- Orders by JourneyID
            ) AS row_num  -- Assigns a row number to each row within the partition to identify duplicates
        FROM
            MarketingAnalytics.dbo.customer_journey
    ) AS subquery  -- Names the subquery for reference in the outer query
WHERE
    row_num = 1;  -- Keeps only the first occurrence of each duplicate group identified in the subquery

```

```sql
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
```

```sql
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
```

# Enreching

- Using python and nltk we can enrich the data by sentiment analysis by categorizing the sentiments and bin them to get more insights on customers reviews data

Here is how the sentiment analysis is conducted:

```python
import pandas as pd
import pyodbc
import nltk
from nltk.sentiment.vader import SentimentIntensityAnalyzer

nltk.download('vader_lexicon')

# function to fetch data from a SQL database using a SQL query
def fetch_data_from_sql():

    conn_str = (
        "Driver={SQL Server};"
        "Server=DESKTOP-7R8JJ6P\MYSQLSERVER;"
        "Database=MarketingAnalytics;"
        "Trusted_Connection=yes;"
    )
    # Establish the connection to the database
    conn = pyodbc.connect(conn_str)

    # the SQL query
    query = "SELECT ReviewID, CustomerID, ProductID, ReviewDate, Rating, ReviewText FROM customer_reviews"

    # Execute the query and fetch the data into a DataFrame
    df = pd.read_sql(query, conn)

    # Closing up the connection to free up resources
    conn.close()

    # the fetched data as a DataFrame
    return df

# Fetch the customer reviews data from the SQL database
customer_reviews_df = fetch_data_from_sql()

# the VADER sentiment intensity analyzer for analyzing the sentiment of text data
sia = SentimentIntensityAnalyzer()

# function to calculate sentiment scores using VADER
def calculate_sentiment(review):
    # Get the sentiment scores for the review text
    sentiment = sia.polarity_scores(review)
    # compound score, which is a normalized score between -1 and 1
    return sentiment['compound']

# function to categorize sentiment using both the sentiment score and the review rating
def categorize_sentiment(score, rating):
    # Use both the text sentiment score and the numerical rating to determine sentiment category
    if score > 0.05:
        if rating >= 4:
            return 'Positive'
        elif rating == 3:
            return 'Mixed Positive'
        else:
            return 'Mixed Negative'
    elif score < -0.05:
        if rating <= 2:
            return 'Negative'
        elif rating == 3:
            return 'Mixed Negative'
        else:
            return 'Mixed Positive'
    else:
        if rating >= 4:
            return 'Positive'
        elif rating <= 2:
            return 'Negative'
        else:
            return 'Neutral'

# Define a function to bucket sentiment scores into text ranges
def sentiment_bucket(score):
    if score >= 0.5:
        return '0.5 to 1.0'  # Strongly positive sentiment
    elif 0.0 <= score < 0.5:
        return '0.0 to 0.49'  # Mildly positive sentiment
    elif -0.5 <= score < 0.0:
        return '-0.49 to 0.0'  # Mildly negative sentiment
    else:
        return '-1.0 to -0.5'  # Strongly negative sentiment

# sentiment analysis to calculate sentiment scores for each review
customer_reviews_df['SentimentScore'] = customer_reviews_df['ReviewText'].apply(calculate_sentiment)

# sentiment categorization using both text and rating
customer_reviews_df['SentimentCategory'] = customer_reviews_df.apply(
    lambda row: categorize_sentiment(row['SentimentScore'], row['Rating']), axis=1)

# sentiment bucketing to categorize scores into defined ranges
customer_reviews_df['SentimentBucket'] = customer_reviews_df['SentimentScore'].apply(sentiment_bucket)

# Display the first rows
print(customer_reviews_df.head())

# Save the DataFrame with sentiment scores, categories, and buckets to a new CSV file
customer_reviews_df.to_csv('fact_customer_reviews_with_sentiment.csv', index=False)
```

Here is the result of csv file which will be merged with the Customer Reviews table:

![1](https://github.com/user-attachments/assets/bb6520fe-bd63-4678-8276-fefea51569b6)


# Visualization

## Results

- What does the dashboard look like?
  
  1.This shows the Conversion Rate details:

  ![2](https://github.com/user-attachments/assets/bcd971ff-4488-4ab0-851f-3f06861bed9f)


  2.This shows the Social Media Metrics details:

  ![3](https://github.com/user-attachments/assets/343d1a19-17bf-48fa-b405-7f157a38789f)


  3.This shows the Customer Reviews details:

  ![4](https://github.com/user-attachments/assets/ee775d6c-7f7d-42fb-afb6-cf17708b782e)


## DAX Measures

### 1. Conversion Rate

```sql
Conversion Rate =
VAR TotalVisitors = CALCULATE(Count(fact_customer_journey[JourneyID]) , fact_customer_journey[Action] = "View")
VAR TotalPurchases = CALCULATE(COUNT(fact_customer_journey[JourneyID]), fact_customer_journey[Action] = "Purchase")
RETURN
IF(
    TotalVisitors = 0,
    0,
    DIVIDE(TotalPurchases,TotalVisitors)
)

```

### 2. Totals for Social Media

```sql
Views = sum('fact_engagement_data'[Views])
Clicks = SUM('fact_engagement_data'[Clicks])
Likes = SUM('fact_engagement_data'[Likes])
```

### 3. Average Rating

```sql
Average Rating = AVERAGE('customer_review_sentiment'[Rating])

```

### 4. Number of Campaigns

```sql
Number of Campaigns = DISTINCTCOUNT('fact_engagement_data'[CampaignID])

```

### 5. Number of Customer Reviews

```sql
Number of Customer Reviews = DISTINCTCOUNT('customer_review_sentiment'[ReviewID])

```

# Analysis

## Findings

- What did we find?

For this analysis, we're going to focus on the questions below to get the information we need for our marketing team :

### 1. Where is the stage that most customers drop-off on?

![5](https://github.com/user-attachments/assets/b1a2957a-655d-49c6-9c80-a0dfaac963bc)


Our data shows that a significant portion of potential customers (49%) are dropping off in the Click action just after View when browsing our website. This suggests that there may be opportunities to improve the user experience and encourage more customers to click through.

### 2. What are the time periods we best perform in term of conversion rate ?

![6](https://github.com/user-attachments/assets/f7fed649-887d-451b-85d7-a4c4091a346b)


Our data shows that our conversion rate is highest during the holiday season, specifically in December and January. This suggests that customers are more likely to make a purchase during this time of year.

### 3. Which content type generates more engagement from the customers ?

![7](https://github.com/user-attachments/assets/76a275f0-952a-4500-8539-631265a5f41b)


Our data shows that social media content consistently generates a high volume of views over time, while blog content tends to experience peaks in viewership during specific months, coinciding with periods of strong social media performance. And that newsletter and video content types have demonstrated suboptimal performance over time.

### 4. Which content type generates the least engagement from the customers ?

![8](https://github.com/user-attachments/assets/a5b539b8-40b2-4ec1-b96c-c7f8c654da73)


Our data indicates that newsletter and video content types have demonstrated suboptimal performance over time, despite occasional successes with specific marketing campaigns for particular months and products.

### 5. What are the reccuring themes in customer reviews that we can enhance ?

![9](https://github.com/user-attachments/assets/533285d9-d982-4cb0-8574-36eb46b094d5)


Our data shows that 65% of product reviews for breakable products (hockey sticks, tennis rackets, and surfboards) are either mixed negative or negative. This suggests that there may be a problem with the quality of these products.

# Recommendations

- Based on the insights gathered i can reccomend :

1. Website design and call to action: Make sure your website is easy to navigate and use. Use clear and concise language.And make it easy for customers to take the next step by including clear calls to action.
2. Take advantage of the trends in holidays season : start your holiday marketing campaigns early and run holiday-themed marketing campaigns, all offering discounts and promotions.
3. Social media: Develop a consistent posting schedule to maintain audience engagement. Experiment with different content formats to identify what resonates most with your followers. Blog content: Focus on creating high-quality, evergreen content that remains relevant over time. Promote blog posts across various channels, including social media, to maximize reach.
4. Newsletter content: Re-evaluate the content strategy for newsletters. Consider incorporating more engaging and relevant content, such as personalized recommendations, exclusive offers, or behind-the-scenes glimpses. Video content: Explore alternative video formats or topics that may resonate better with the target audience. Consider shorter, more visually appealing videos or collaborations with influencers to increase engagement.
5. Product quality: Investigate the quality of these products. Identify any defects or design flaws that may be contributing to negative reviews.And reach out to customers who have left negative reviews. Offer a refund or replacement if the product is defective.

# Conclusion

This business case aimed to analyze the marketing performance of an online retailer struggling with customer engagement and conversion rates. Through a comprehensive data analysis approach, leveraging SQL for data cleaning and enrichment, Python with NLTK for sentiment analysis, and Power BI for visualization, we identified key areas for improvement.

Our findings revealed several critical insights:

- A significant customer drop-off occurs between product viewing and clicking, indicating potential website usability issues.
- Conversion rates peak during the holiday season, highlighting the need for targeted holiday marketing strategies.
- Social media and blog content are the most effective engagement drivers, while newsletter and video content underperform.
- A high proportion of negative reviews for specific product categories (breakable items) points to product quality concerns.

Based on these insights, i recommended actions in the last part by implementing these recommendations, the online retailer can expect to see improved customer engagement, higher conversion rates, and increased customer satisfaction, ultimately driving business growth. This data-driven approach allows for continuous monitoring and optimization of marketing strategies, ensuring a competitive edge in the dynamic online retail market.
