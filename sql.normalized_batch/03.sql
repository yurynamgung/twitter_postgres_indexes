/*
 * Calculates the hashtags that are commonly used with the hashtag #coronavirus
 */
SELECT
    lang,
    count(*) as count
FROM (
    SELECT DISTINCT t2.id_tweets,lang
    FROM tweet_tags t1
    JOIN tweet_tags t2 ON t1.id_tweets = t2.id_tweets
    JOIN tweets ON t2.id_tweets = tweets.id_tweets
    WHERE t1.tag='#coronavirus'
      AND t2.tag LIKE '#%'
) t
GROUP BY lang
ORDER BY count DESC,lang;

