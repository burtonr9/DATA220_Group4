-- W4, worked example: Which trail locations are the busiest?
-- An INNER JOIN, as in Wednesday's lecture: trail_counts has the trips, counters has
-- the location and trail type; counter_id is in both tables.
--
--   FROM trail_counts AS t          the main table, called t for short
--   INNER JOIN counters AS c        the table with the details, called c
--     ON t.counter_id = c.counter_id   which rows belong together
--   GROUP BY c.location ...         one result row per location
--
-- Run this file, read the result, then answer on the ANSWER line below.
-- ANSWER: the busiest location is Hawrelak Park Trail
SELECT c.location, c.trail_type, SUM(t.trips) AS total_trips
FROM trail_counts AS t
INNER JOIN counters AS c ON t.counter_id = c.counter_id
GROUP BY c.location, c.trail_type
ORDER BY total_trips DESC
