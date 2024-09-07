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
END_TIME="000000"

for TARGET in min_temp_point max_temp_point
do
  echo "TARGET: ${TARGET}"
  URL="https://www.jma.go.jp/bosai/jmatile/data/wdist/${START_DATE}${START_TIME}/none/${END_DATE}${END_TIME}/surf/${TARGET}/data.geojson?id=${TARGET}"
  
  echo "fetch URL: ${URL}"
  
  DIR="data/${START_DATE}${START_TIME}-${END_DATE}${END_TIME}"
  mkdir -p $DIR

  curl -s $URL |
    jq . > "${DIR}/${TARGET}.geojson"

  echo "saved to ${DIR}/${TARGET}.geojson"
done
