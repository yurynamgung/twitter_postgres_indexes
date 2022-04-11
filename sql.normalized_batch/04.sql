/*
 * Calculates the hashtags that are commonly used for English tweets containing the word "coronavirus"
 */
SELECT
    count(*)
FROM tweets
WHERE to_tsvector('english',text)@@to_tsquery('english','coronavirus')
  AND lang='en'
;
