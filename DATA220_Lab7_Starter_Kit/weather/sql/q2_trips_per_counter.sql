-- W3, question 2: How many days and how many trips did each counter report?
-- Show:  counter_id, the number of rows (COUNT(*)), the total trips, and the average
--        daily trips rounded to 1 decimal -- the busiest counter (most trips) first
-- Table: trail_counts
-- Uses:  COUNT(*), SUM(), AVG(), ROUND(), GROUP BY, ORDER BY ... DESC   (Week 9, Wednesday)
SELECT counter_id,
       COUNT(*)             AS days,
       SUM(trips)           AS total_trips,
       ROUND(AVG(trips), 1) AS avg_daily_trips
FROM trail_counts
GROUP BY counter_id
ORDER BY total_trips DESC;

