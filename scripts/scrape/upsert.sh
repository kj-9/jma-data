#!/bin/bash

set -eu -o pipefail

# constants
FILE_DB="data/jma.db"
ROWS_AFFECTED="data/tmp/rows_affected.txt"

# alias
splite() {
    sqlite-utils --load-extension=spatialite "$FILE_DB" "$@"
}

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


echo "upsert to \`dates\`..."
q=$(cat <<EOF
insert or ignore into dates (valid_date)
select substr(:valid_time, 1, 8);
EOF
)
splite "$q" \
    -p valid_time $VALIDTIME \
    | jq '.[0].rows_affected' | tee -a $ROWS_AFFECTED


echo "load geojson to \`$TABLE_INGEST\`..."
splite "select ImportGeoJSON('$FILE_GEOJSON', '$TABLE_INGEST')" \

#splite "select * from $TABLE_INGEST limit 10"



echo "upsert to \`points\`..."
q=$(cat <<EOF
insert or ignore into points(geometry)
select geometry from $TABLE_INGEST;
EOF
)
splite "$q" \
  | jq '.[0].rows_affected' | tee -a $ROWS_AFFECTED
#splite "select * from points limit 10"


echo "upsert to \`temperature\`..."
q=$(cat <<EOF
insert into temperature (date_id, point_id, $TABLE_APPEND)
select dates.date_id, points.point_id, value
from $TABLE_INGEST
  left join points using (geometry)
  cross join (select date_id from dates where valid_date=substr(:valid_time, 1, 8)) as dates
where true
ON CONFLICT(date_id, point_id) DO UPDATE SET $TABLE_APPEND=excluded.$TABLE_APPEND;
EOF
)
splite "$q" -p valid_time $VALIDTIME \
  | jq '.[0].rows_affected' | tee -a $ROWS_AFFECTED
#splite "select * from $TABLE_APPEND order by $TABLE_APPEND limit 1";


echo "cleanup..."
echo "drop table \`$TABLE_INGEST\`..."
splite "select DropTable('main', '$TABLE_INGEST')"

echo "remove $FILE_GEOJSON..."
rm -f $FILE_GEOJSON
