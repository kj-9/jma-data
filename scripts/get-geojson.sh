#!/bin/bash

set -eu -o pipefail


# Download the targetTimes.json file
curl -s https://www.jma.go.jp/bosai/jmatile/data/wdist/targetTimes.json > /tmp/targetTimes.json

# get a table of basetime, validtime, and element to be scraped
extract_table() {
  local element=$1
  jq -r --arg element "$element" '.[] | select(.elements | index($element)) | "\(.basetime) \(.validtime) \($element)"' /tmp/targetTimes.json
}

min_table=$(extract_table "min_temp_point")
max_table=$(extract_table "max_temp_point")

table="$min_table"$'\n'"$max_table"

# Loop through the table
echo "$table" | while read -r basetime validtime element; do
  
  # Use the extracted basetime, validtime, and element
  echo "Basetime: $basetime, Validtime: $validtime, Element: $element"
  
  # Example usage in a URL
  url="https://www.jma.go.jp/bosai/jmatile/data/wdist/${basetime}/none/${validtime}/surf/${element}/data.geojson?id=${element}"
  echo "fetch URL: ${url}"

  data_dir="data/tmp"
  mkdir -p $data_dir
  
  curl -s $url > "${data_dir}/${basetime}-${validtime}-${element}.geojson"

done
