CREATE TABLE sample AS SELECT * FROM read_csv_auto('../sample.csv', header=true);
CREATE TABLE cities AS SELECT * FROM read_csv_auto('simplemaps_cities.csv', header=true);
CREATE TABLE centers AS SELECT * FROM read_csv_auto('census_centers.csv', header=true);
CREATE TABLE energy AS SELECT * FROM read_csv_auto('../env/data_energy.csv', header=true);

CREATE MACRO PARSE(x) AS
  CASE
    WHEN x IS NULL THEN NULL
    WHEN x = '#REF!' THEN NULL
    WHEN x = ' -   ' THEN NULL
    ELSE CAST(REPLACE(x, ',', '') AS INT)
  END;

CREATE TABLE dist AS
SELECT
    c.city,
    c.state_id,
    SUM(
      SQRT(
        POWER((CAST(ct.LATITUDE AS FLOAT) - c.lat) * 111.32, 2) +
        POWER((ct.LONGITUDE - c.lng) * 111.32 * COS(RADIANS((c.lat + CAST(ct.LATITUDE AS FLOAT)) / 2)), 2)
      ) * ct.POPULATION
    ) / SUM(ct.POPULATION) AS average_dist
FROM cities c
CROSS JOIN centers ct
WHERE c.population > 50000
GROUP BY c.city, c.state_id;

CREATE TABLE out AS
SELECT
  c.city,
  c.state_id as state,
  c.lat as latitude,
  c.lng as longitude,
  c.population,
  c.density,
  d.average_dist,
  PARSE(e."Residential Electricity  GHG emissions (mtons CO2e)") as residential_elec_co2e,
  PARSE(e."Residential Natural Gas  GHG emissions (mtons CO2e)") AS residential_gas_co2e,
  PARSE(e."Commercial Electricity  GHG emissions (mtons CO2e)") AS commercial_elec_co2e,
  PARSE(e."Commercial Natural Gas  GHG emissions (mtons CO2e)") AS commercial_gas_co2e,
  PARSE(e."Industry Electricity  GHG emissions (mtons CO2e)") AS industry_elec_co2e,
  PARSE(e."Industry Natural Gas  GHG emissions (mtons CO2e)") AS industry_gas_co2e,
  PARSE(e."On-road Transportation Gasoline  GHG emissions (mtons CO2e)") AS transport_gas_co2e,
  PARSE(e."On-road Transportation Diesel  GHG emissions (mtons CO2e)") AS transport_diesel_co2e
FROM sample s
LEFT JOIN cities c
  ON c.city = s.city AND c.state_id = s.state
LEFT JOIN dist d
  ON d.city = c.city AND d.state_id = c.state_id
LEFT JOIN energy e
  ON e.city_name = c.city || ' city' AND e.state_abbr = c.state_id
WHERE c.population > 50000
GROUP BY
  c.city,
  c.state_id,
  c.state_name,
  c.population,
  c.density,
  c.lat,
  c.lng,
  d.average_dist,
  residential_elec_co2e,
  residential_gas_co2e,
  commercial_elec_co2e,
  commercial_gas_co2e,
  industry_elec_co2e,
  industry_gas_co2e,
  transport_gas_co2e,
  transport_diesel_co2e;

COPY out TO 'output.csv' (FORMAT CSV, HEADER TRUE);
