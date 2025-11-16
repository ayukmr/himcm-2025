CREATE TABLE sample AS SELECT * FROM read_csv_auto('../sample.csv', header=true);
CREATE TABLE cities AS SELECT * FROM read_csv_auto('simplemaps_cities.csv', header=true);
CREATE TABLE flights AS SELECT * FROM read_csv_auto('bts_flights.csv', header=true);
CREATE TABLE visits AS SELECT * FROM read_csv_auto('trade_visits.csv', header=true);
CREATE TABLE aqi AS SELECT * FROM read_csv_auto('epa_aqi.csv', header=true);
CREATE TABLE tmean AS SELECT * FROM read_csv_auto('prism_tmean.csv', header=true);
CREATE TABLE tdmean AS SELECT * FROM read_csv_auto('prism_tdmean.csv', header=true);
CREATE TABLE centers AS SELECT * FROM read_csv_auto('census_centers.csv', header=true);

CREATE TABLE out AS
SELECT
  s.city,
  s.state,
  c.state_name as state_long,
  s.airport,
  c.lat,
  c.lng,
  c.population,
  f.count AS flights,
  a."Median AQI" AS aqi,
  AVG(t.val) AS temp,
  AVG(td.val) AS dew_pt,
  SUM(
    SQRT(
      POWER((CAST(ct.LATITUDE AS FLOAT) - c.lat) * 111.32, 2) +
      POWER((ct.LONGITUDE - c.lng) * 111.32 * COS(RADIANS((c.lat + CAST(ct.LATITUDE AS FLOAT)) / 2)), 2)
    ) * ct.POPULATION
  ) / SUM(ct.POPULATION) AS dist,
  CAST(REPLACE(v."2024 VISITATION (000)", ',', '') AS INT) * 100 / c.population AS visit_rate
FROM sample s
LEFT JOIN cities c
  ON c.city = s.city AND c.state_id = s.state
LEFT JOIN flights f
  ON f.dest = s.airport
LEFT JOIN visits v
  ON POSITION(s.city IN v."CITY (MSA)  VISITATION**") > 0
  AND POSITION(s.state IN v."CITY (MSA)  VISITATION**") > 0
LEFT JOIN aqi a
  ON POSITION(s.city IN a.CBSA) > 0
  AND ENDS_WITH(a.CBSA, s.state)
LEFT JOIN tmean t
  ON ABS(t.lat - c.lat) < 0.036 AND ABS(t.lng - c.lng) < 0.05
LEFT JOIN tdmean td
  ON ABS(td.lat - c.lat) < 0.036 AND ABS(td.lng - c.lng) < 0.05
CROSS JOIN centers ct
GROUP BY s.city, s.state, c.state_name, s.airport, c.population, c.lat, c.lng, f.count, visit_rate, aqi;

COPY out TO 'output.csv' (FORMAT CSV, HEADER TRUE);
