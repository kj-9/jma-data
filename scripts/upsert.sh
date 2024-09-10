#!/bin/bash

set -eu -o pipefail

# constants
FILE_DB="data/jma.db"
ROWS_AFFECTED="data/tmp/rows_affected.txt"

# args
FILE_GEOJSON=$1 # "data/tmp/20240909080000-20240910000000-min_temp_point.geojson"

# drived
# min_temp
TABLE_APPEND=$(basename $FILE_GEOJSON | cut -d'-' -f3 | cut -d'.' -f1 | sed 's/_point//')
TABLE_INGEST="${TABLE_APPEND}_ingest"

# 20240909080000
BASETIME=$(basename $FILE_GEOJSON | cut -d'-' -f1)
# 20240910000000
VALIDTIME=$(basename $FILE_GEOJSON | cut -d'-' -f2)

echo "TABLE_INGEST: $TABLE_INGEST"
echo "BASETIME: $BASETIME"
echo "VALIDTIME: $VALIDTIME"

# for import geojson using spatialite
export SPATIALITE_SECURITY=relaxed

echo "upsert to \`times\`..."
q=$(cat <<EOF
insert or ignore into times (base_time, valid_time)
values (:base_time, :valid_time);
EOF
)
sqlite-utils $FILE_DB "$q" \
    -p base_time $BASETIME -p valid_time $VALIDTIME \
    | jq '.[0].rows_affected' | tee -a $ROWS_AFFECTED


echo "load geojson to \`$TABLE_INGEST\`..."
sqlite-utils --load-extension=spatialite \
    $FILE_DB "select ImportGeoJSON('$FILE_GEOJSON', '$TABLE_INGEST')" \

#sqlite-utils $FILE_DB "select * from $TABLE_INGEST limit 10"



echo "upsert to \`points\`..."
q=$(cat <<EOF
insert or ignore into points(geometry)
select geometry from $TABLE_INGEST;
EOF
)
sqlite-utils $FILE_DB "$q" \
  | jq '.[0].rows_affected' | tee -a $ROWS_AFFECTED
#sqlite-utils $FILE_DB "select * from points limit 10"


echo "upsert to \`$TABLE_APPEND\`..."
q=$(cat <<EOF
insert into $TABLE_APPEND
select times.time_id, points.point_id, value
from $TABLE_INGEST
  left join points using (geometry)
  cross join (select time_id from times where base_time=:base_time and valid_time=:valid_time) as times
where true
ON CONFLICT(time_id, point_id) DO UPDATE SET $TABLE_APPEND=excluded.$TABLE_APPEND;
EOF
)
sqlite-utils $FILE_DB "$q" -p base_time $BASETIME -p valid_time $VALIDTIME \
  | jq '.[0].rows_affected' | tee -a $ROWS_AFFECTED
#sqlite-utils $FILE_DB "select * from $TABLE_APPEND order by $TABLE_APPEND limit 1";


echo "cleanup..."
echo "drop table \`$TABLE_INGEST\`..."
sqlite-utils --load-extension=spatialite $FILE_DB "select DropTable('main', '$TABLE_INGEST')"

echo "remove $FILE_GEOJSON..."
rm -f $FILE_GEOJSON

echo "vacuum db..."
sqlite-utils vacuum $FILE_DB

echo "file size:"
ls -lah $FILE_DB
