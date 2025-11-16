CREATE TABLE pred AS SELECT * FROM read_csv_auto('pred.csv', header=true);
CREATE TABLE games AS SELECT * FROM read_csv_auto('kaggle_games.csv', header=true);

CREATE TABLE agg AS
SELECT
  p.city,
  p.state,
  p.state_long,
  p.airport,
  p.dist,
  p.visit_rate,
  AVG(g.Attendance) AS attendance
FROM pred p
LEFT JOIN games g
  ON g.City = p.city || ', ' || p.state_long
GROUP BY p.city, p.state, p.state_long, p.airport, p.dist, p.visit_rate;

CREATE TABLE out AS
SELECT
  city,
  state,
  state_long,
  airport,
  dist,
  visit_rate,
  attendance / SUM(attendance) OVER () AS attendance
FROM agg;

COPY out TO 'games.csv' (FORMAT CSV, HEADER TRUE);
