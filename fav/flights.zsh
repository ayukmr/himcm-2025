echo 'dest,count' > bts_flights.csv
awk -F',' '{count[$2]++} END {for (d in count) print d "," count[d]}' bts.csv >> bts_flights.csv
