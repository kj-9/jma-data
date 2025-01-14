#!/bin/bash
set -eu -o pipefail

# constants
FILE_DB_GZ="data/jma.db.gz"
FILE_DB="data/jma.db"

echo "get geojson ..."
bash scripts/scrape/get-geojson.sh

echo "upsert geojson ..."

du -h $FILE_DB_GZ

echo "gunzip ${FILE_DB_GZ} ..."
gunzip -fk $FILE_DB_GZ

du -h $FILE_DB


find data/tmp -type f -name "*.geojson" | xargs -I {} bash scripts/scrape/upsert.sh {}

echo "vacuum db..."
sqlite-utils vacuum $FILE_DB

du -h $FILE_DB

echo "gzip ${FILE_DB} ..."
gzip -f $FILE_DB

du -h $FILE_DB_GZ
