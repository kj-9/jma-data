#!/bin/bash
set -eu -o pipefail

# constants
FILE_DB="data/jma.db"

# init db if not exists
# if there is not $FILE_DB, create it
if [ ! -f $FILE_DB ]; then
    sqlite-utils create-database $FILE_DB --init-spatialite
fi


# create tables
echo "create if not exists \`times\` table..."
sqlite-utils $FILE_DB '
create table if not exists times (
    time_id INTEGER PRIMARY KEY not null,
    base_time TEXT not null,
    valid_time TEXT not null,
    unique (base_time, valid_time)
);'

echo "create if not exists \`points\` table..."
sqlite-utils --load-extension=spatialite $FILE_DB '
create table if not exists points (
    point_id INTEGER PRIMARY KEY not null
);'

sqlite-utils --load-extension=spatialite $FILE_DB '
select AddGeometryColumn('points', 'geometry', 4326, 'POINT', 2, 1);'


echo "create if not exists \`min_temp\` table..."
sqlite-utils --load-extension=spatialite $FILE_DB '
create table if not exists min_temp (
    time_id INTEGER not null,
    point_id INTEGER not null,
    min_temp not null,
    primary key (time_id, point_id)
    foreign key (time_id) references times (time_id)
    foreign key (point_id) references points (point_id)
);'

echo "create if not exists \`max_temp\` table..."
sqlite-utils --load-extension=spatialite $FILE_DB '
create table if not exists max_temp (
    time_id INTEGER not null,
    point_id INTEGER not null,
    max_temp not null,
    primary key (time_id, point_id)
    foreign key (time_id) references times (time_id)
    foreign key (point_id) references points (point_id)
);'
