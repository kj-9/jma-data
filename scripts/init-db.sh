#!/bin/bash
set -eu -o pipefail

# constants
FILE_DB="data/jma.db"

# alias
splite() {
    sqlite-utils --load-extension=spatialite "$FILE_DB" "$@"
}

# init db if not exists
# if there is not $FILE_DB, create it
if [ ! -f $FILE_DB ]; then
    sqlite-utils create-database $FILE_DB --init-spatialite
fi

# create tables
echo "create if not exists \`dates\` table..."
splite '
create table if not exists dates (
    date_id INTEGER primary key not null,
    valid_date TEXT not null unique
);'


echo "create if not exists \`points\` table..."
splite '
create table if not exists points (
    point_id INTEGER PRIMARY KEY not null
);'

splite "select AddGeometryColumn('points', 'geometry', 4326, 'POINT', 2, 1);"
splite 'CREATE UNIQUE INDEX point_geometry_uq_idx ON points(geometry)';


echo "create if not exists \`temperature\` table..."
splite '
create table if not exists temperature (
    date_id INTEGER not null,
    point_id INTEGER not null,
    min_temp INTEGER,
    max_temp INTEGER,
    primary key (date_id, point_id),
    foreign key (date_id) references dates(date_id)
    foreign key (point_id) references points(point_id)
);'
