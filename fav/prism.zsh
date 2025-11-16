file="$1"
new="${file:t:r}"

gdal_translate -of XYZ "$file" "$new.xyz"

echo 'lat,lng,val' > "$new.csv"
awk '{print $2","$1","$3}' "$new.xyz" >> "$new.csv"
