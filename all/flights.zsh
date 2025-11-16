echo 'dest,count' > bts_flights.csv
awk '{sub(/\r$/, ""); count[$0]++} END {for (d in count) print d "," count[d]}' bts.csv >> bts_flights.csv
