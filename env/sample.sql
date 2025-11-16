CREATE TABLE sample AS SELECT * FROM read_csv_auto('../sample.csv', header=true);
CREATE TABLE energy AS SELECT * FROM read_csv_auto('data_energy.csv', header=true);

CREATE MACRO PARSE(x) AS
  CASE
    WHEN x IS NULL THEN NULL
    WHEN x = '#REF!' THEN NULL
    WHEN x = ' -   ' THEN NULL
    ELSE CAST(REPLACE(x, ',', '') AS INT)
  END;

CREATE TABLE out AS
SELECT
  s.city,
  s.state,
  s.airport,
  (
    PARSE(e."Residential Electricity  GHG emissions (mtons CO2e)") +
    PARSE(e."Residential Natural Gas  GHG emissions (mtons CO2e)") +
    PARSE(e."Commercial Electricity  GHG emissions (mtons CO2e)") +
    PARSE(e."Commercial Natural Gas  GHG emissions (mtons CO2e)") +
    PARSE(e."Industry Electricity  GHG emissions (mtons CO2e)") +
    PARSE(e."Industry Natural Gas  GHG emissions (mtons CO2e)") +
    PARSE(e."On-road Transportation Gasoline  GHG emissions (mtons CO2e)") +
    PARSE(e."On-road Transportation Diesel  GHG emissions (mtons CO2e)")
  ) / PARSE(e.population) AS per_capita
FROM sample s
LEFT JOIN energy e
  ON e.city_name = s.city || ' city' AND e.state_abbr = s.state;

COPY out TO 'output.csv' (FORMAT CSV, HEADER TRUE);
