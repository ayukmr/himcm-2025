CREATE TABLE centers AS SELECT * FROM read_csv_auto('census_centers.csv', header=true);

CREATE TABLE locs AS
WITH
  lat AS (
    SELECT 32.5 + r.range * 0.25 AS lat
    FROM range(0, ceil((42.0 - 32.5) / 0.25)::int) r
  ),
  lng AS (
    SELECT -124.4 + r.range * 0.25 AS lng
    FROM range(0, ceil((-114.1 - -124.4) / 0.25)::int) r
  )
SELECT lat, lng
FROM lat
CROSS JOIN lng
ORDER BY lat, lng;

CREATE TABLE out AS
SELECT
  l.lat as latitude,
  l.lng as longitude,
  SUM(
    SQRT(
      POWER((CAST(ct.LATITUDE AS FLOAT) - l.lat) * 111.32, 2) +
      POWER((ct.LONGITUDE - l.lng) * 111.32 * COS(RADIANS((l.lat + CAST(ct.LATITUDE AS FLOAT)) / 2)), 2)
    ) * ct.POPULATION
  ) / SUM(ct.POPULATION) AS average_dist
FROM locs l
CROSS JOIN centers ct
GROUP BY l.lat, l.lng;

COPY out TO 'locs.csv' (FORMAT CSV, HEADER TRUE);
