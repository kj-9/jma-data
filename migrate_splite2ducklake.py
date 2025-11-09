import marimo

__generated_with = "0.17.7"
app = marimo.App(width="columns")


@app.cell(column=0)
def _():
    import marimo as mo
    return (mo,)


@app.cell
def _():
    import subprocess
    import gzip
    import json
    from pathlib import Path
    return Path, gzip, subprocess


@app.cell(column=1)
def _(mo):
    mo.md(r"""
    ## Exporting Sqlite db to geo/json
    """)
    return


@app.cell
def _(Path, subprocess):
    def run_cmd(cmd: str):
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            print("Error executing command:")
            print(result.stderr)
            raise subprocess.CalledProcessError(result.returncode, cmd)

        return result


    def ensure_data_tmp_dir():
        tmp_dir = Path("data/tmp")
        tmp_dir.mkdir(parents=True, exist_ok=True)
        return tmp_dir
    return ensure_data_tmp_dir, run_cmd


@app.cell
def _(Path, ensure_data_tmp_dir, gzip):
    # ungzip
    tmp_dir = ensure_data_tmp_dir()

    gz_files = Path.cwd().glob("data/jma.db.gz*")
    db_files = []

    for _i, _file in enumerate(gz_files):
        print(f"Decompressing {_file}...")
        with gzip.open(_file, 'rb') as _opened_file:
            _db_file = tmp_dir / f"jma_part_{_i}.db"
            _db_file.write_bytes(_opened_file.read())
            print(f"Decompressed to {_db_file}")
            db_files.append(_db_file)
    return (db_files,)


@app.cell
def _(db_files, run_cmd):
    # run bash command to export sqlite db to geojson
    # `points` table has geometry column so exporting as .geojson
    print("Exporting points table to GeoJSON...")
    for _i, _file in enumerate(db_files):
        print(f"Processing {_file}...")
        run_cmd(f"""SPATIALITE_SECURITY=relaxed sqlite-utils --load-extension=spatialite {_file} "select ExportGeoJSON2('points', 'geometry', 'data/tmp/points-{_i}.geojson')"
    """)
        print(f"Exported points table to data/tmp/points-{_i}.geojson")

    # export `dates` table to json
    # `dates` table has no geometry column so exporting as .json
    print("Exporting dates table to JSON...")

    for _i, _file in enumerate(db_files):
        print(f"Processing {_file}...")
        run_cmd(f"""sqlite-utils --load-extension=spatialite {_file} "SELECT {_i} as file_id, valid_date as at_date, point_id, min_temp, max_temp FROM temperature left join dates using(date_id)" > data/tmp/temperature-{_i}.json""")
        print(f"Exported dates table to data/tmp/dates-{_i}.json")
    return


@app.cell(column=2)
def _():
    import duckdb
    engine = duckdb.connect(read_only=False)
    engine.install_extension("spatial")
    engine.load_extension("spatial")
    engine.install_extension("ducklake")
    engine.execute("""
    ATTACH 'ducklake:data/jma.ducklake' AS jma_ducklake (DATA_PATH 'data/');
    USE jma_ducklake;
    FROM jma_ducklake.options();
    """)
    return (engine,)


@app.cell
def _(engine, mo):
    _ = mo.sql(
        f"""
        -- error! ducklake does not surpport spatial yet.
        -- see: https://github.com/duckdb/ducklake/issues/32
        -- update: fixed as of 2025/11/9
        CREATE OR REPLACE TABLE points AS
        --SELECT ST_Point(0,1)
        SELECT * FROM ST_Read('data/tmp/points-0.geojson')
        UNION
        SELECT * FROM ST_Read('data/tmp/points-1.geojson')
        ORDER BY point_id
        ;
        """,
        engine=engine
    )
    return


@app.cell
def _(engine, mo, points):
    _df = mo.sql(
        f"""
        SELECT * exclude geom, st_astext(geom)
        FROM points
        """,
        engine=engine
    )
    return


@app.cell
def _(engine, mo, points):
    _df = mo.sql(
        f"""
        SELECT max(point_id), count(1), count(distinct point_id)
        FROM points
        """,
        engine=engine
    )
    return


@app.cell
def _(engine, mo, temperature_all):
    _df = mo.sql(
        f"""
        CREATE OR REPLACE TABLE temperature (
            at_date DATE NOT NULL,
            point_id INTEGER NOT NULL,
            min_temp INTEGER,
            max_temp INTEGER
        );

        ALTER TABLE temperature SET PARTITIONED BY (year(at_date), month(at_date), day(at_date));

        INSERT INTO temperature
        with temperature_all as (
        select *
        FROM read_json('data/tmp/temperature-0.json')
        UNION ALL
        FROM read_json('data/tmp/temperature-1.json')
        )

        select strptime(at_date, '%Y%m%d') as at_date, point_id, min_temp, max_temp
        from temperature_all
        QUALIFY
        	row_number() OVER (PARTITION BY at_date ORDER BY file_id) = 1 -- pick from latest file
        order by at_date, point_id
        """,
        engine=engine
    )
    return


@app.cell
def _(engine, mo):
    _df = mo.sql(
        f"""
        with temperature_all as (
        select *
        FROM read_json('data/tmp/temperature-0.json')
        UNION ALL
        FROM read_json('data/tmp/temperature-1.json')
        )

        select at_date --strptime(at_date, '%Y%m%d') as at_date, point_id, min_temp, max_temp
        from temperature_all
        group by at_date
        having count(1) > 1
        -- QUALIFY
        --     row_number() OVER (PARTITION BY schema_name ORDER BY function_name) < 3;
        limit 10
        """,
        engine=engine
    )
    return


@app.cell
def _(engine, mo):
    _df = mo.sql(
        f"""
        with temperature_all as (
        select *
        FROM read_json('data/tmp/temperature-0.json')
        UNION ALL
        FROM read_json('data/tmp/temperature-1.json')
        )

        select strptime(at_date, '%Y%m%d') as at_date, point_id, min_temp, max_temp
        from temperature_all
        QUALIFY
        	row_number() OVER (PARTITION BY at_date ORDER BY file_id) = 1 -- pick from latest file
        order by at_date, point_id
        limit 10
        """,
        engine=engine
    )
    return


@app.cell
def _(engine, mo, temperature):
    _df = mo.sql(
        f"""
        select count(1), count(distinct at_date || '-' || point_id)
        from temperature
        """,
        engine=engine
    )
    return


if __name__ == "__main__":
    app.run()
