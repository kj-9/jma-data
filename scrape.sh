#!/bin/bash

set -eu -o pipefail

# Set timezone to JST
export TZ="Asia/Tokyo"

# today and tomorrow
START_DATE=$(date +%Y%m%d)
END_DATE=$(date -v +1d +%Y%m%d || date -d 'tomorrow' +%Y%m%d) # for macOS || ubuntu

echo "START_DATE: ${START_DATE}"
echo "END_DATE: ${END_DATE}"

# seems fixed
START_TIME="080000"

# seems separate
END_TIME_MIN_TEMP="000000"
END_TIME_MAX_TEMP="090000"


# requires bash version >= 4.0
declare -A target_map

target_map["min_temp_point"]=$END_TIME_MIN_TEMP
target_map["max_temp_point"]=$END_TIME_MAX_TEMP

for TARGET in "${!target_map[@]}"; do
  echo "TARGET: ${TARGET}"
  URL="https://www.jma.go.jp/bosai/jmatile/data/wdist/${START_DATE}${START_TIME}/none/${END_DATE}${target_map[$TARGET]}/surf/${TARGET}/data.geojson?id=${TARGET}"
  
  echo "fetch URL: ${URL}"
  
  DIR="data/${END_DATE}"
  mkdir -p $DIR

  curl -s $URL |
    jq . > "${DIR}/${TARGET}.geojson"

  echo "saved to ${DIR}/${TARGET}.geojson"
done
