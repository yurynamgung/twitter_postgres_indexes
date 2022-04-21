/*
 * Calculates the hashtags that are commonly used with the hashtag #coronavirus
 */

SELECT
    tag,
    count(*) as count
FROM (
    SELECT DISTINCT
        data->>'id' AS id_tweets,
        '#' || 
        (jsonb_array_elements(data->'entities'->'hashtags' || COALESCE(data->'extended_tweet'->'entities'->'hashtags', '[]'))->>'text') AS tag -- || joins the arrays
    FROM tweets_jsonb
    WHERE data->'entities'->'hashtags' @@ '$[*].text == "coronavirus"'
       OR data->'extended_tweet'->'entities'->'hashtags' @@ '$[*].text == "coronavirus"'
) t
GROUP BY tag
ORDER BY count DESC, tag
LIMIT 1000;
