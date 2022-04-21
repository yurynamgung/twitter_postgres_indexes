create index on tweets_jsonb USING gin((data->'entities'->'hashtags'));
CREATE INDEX ON tweets_jsonb USING gin((data->'extended_tweet'->'entities'->'hashtags'));

CREATE INDEX ON tweets_jsonb((data->>'lang'), (data->>'id'));
CREATE INDEX ON tweets_jsonb((data->>'lang'))
CREATE INDEX ON tweets_jsonb((data->>'id'));

CREATE INDEX ON tweets_jsonb using gin(to_tsvector('english', COALESCE(data->'extended_tweet'->>'full_text', data->>'text')));
