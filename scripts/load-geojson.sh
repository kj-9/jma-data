set -eu -o pipefail

# constants
FILE_DB="data/jma.db"

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


# init db if not exists
#rm -f $FILE_DB
# if there is not $FILE_DB, create it
if [ ! -f $FILE_DB ]; then
    sqlite-utils create-database $FILE_DB --init-spatialite
fi


# create tables
# times master table
q=$(cat <<EOF
create table if not exists times (
    time_id INTEGER PRIMARY KEY not null,
    base_time TEXT not null,
    valid_time TEXT not null,
    unique (base_time, valid_time)
)
;
EOF
)
sqlite-utils $FILE_DB "$q"

# insert times
sqlite-utils $FILE_DB "insert or ignore into times (base_time, valid_time) values (:base_time, :valid_time)" -p base_time $BASETIME -p valid_time $VALIDTIME

# points master table
q=$(cat <<EOF
create table if not exists points (
    point_id INTEGER PRIMARY KEY not null,
    geometry POINTS not null,
    unique (geometry)
)
--STRICT strict mode cannot use with POINTS
;
EOF
)
sqlite-utils --load-extension=spatialite $FILE_DB "$q"


# min_temp table
q=$(cat <<EOF
create table if not exists min_temp (
    time_id INTEGER not null,
    point_id INTEGER not null,
    min_temp not null,
    primary key (time_id, point_id)
    foreign key (time_id) references times (time_id)
    foreign key (point_id) references points (point_id)
)
;
EOF
)
sqlite-utils --load-extension=spatialite $FILE_DB "$q"

# max_temp table
q=$(cat <<EOF
create table if not exists max_temp (
    time_id INTEGER not null,
    point_id INTEGER not null,
    max_temp not null,
    primary key (time_id, point_id)
    foreign key (time_id) references times (time_id)
    foreign key (point_id) references points (point_id)
)
;
EOF
)
sqlite-utils --load-extension=spatialite $FILE_DB "$q"


# load geojson
sqlite-utils --load-extension=spatialite \
    $FILE_DB "select ImportGeoJSON('$FILE_GEOJSON', '$TABLE_INGEST')" \

#sqlite-utils $FILE_DB "select * from $TABLE_INGEST limit 10"


# insert to points
q=$(cat <<EOF
insert or ignore into points(geometry)
select geometry from $TABLE_INGEST;
EOF
)
sqlite-utils $FILE_DB "$q"
#sqlite-utils $FILE_DB "select * from points limit 10"


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
sqlite-utils $FILE_DB "$q" -p base_time $BASETIME -p valid_time $VALIDTIME
#sqlite-utils $FILE_DB "select * from $TABLE_APPEND order by $TABLE_APPEND limit 1";



# cleanup
sqlite-utils --load-extension=spatialite $FILE_DB "select DropTable('main', '$TABLE_INGEST')"
rm -f $FILE_GEOJSON
sqlite-utils vacuum $FILE_DB

# show file size
ls -lah $FILE_DB
