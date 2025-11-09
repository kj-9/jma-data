import marimo

__generated_with = "0.14.7"
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
    return gzip, subprocess


@app.cell(column=1)
def _(mo):
    mo.md(r"""## Exporting Sqlite db to geo/json""")
    return


@app.cell
def _(gzip):
    # ungzip
    with gzip.open("data/jma.db.gz", 'rb') as gz_file:
        with open("data/jma.db", 'wb') as db_file:
            db_file.write(gz_file.read())
    return


@app.cell
def _(subprocess):
    # run bash command to export sqlite db
    # `points` table
    subprocess.run("""
    SPATIALITE_SECURITY=relaxed sqlite-utils --load-extension=spatialite data/jma.db "select ExportGeoJSON2('points', 'geometry', 'data/tmp/points.geojson')"
    """, shell=True, capture_output=True, text=True)
    return


@app.cell
def _(subprocess):
    # `temerature` table
    subprocess.run("""
    sqlite-utils --load-extension=spatialite data/jma.db "SELECT *  FROM temperature" > data/tmp/temperature.json
    """, shell=True, capture_output=True, text=True)
    return


@app.cell(column=2)
def _():
    import duckdb


    engine = duckdb.connect(read_only=False)
    engine.install_extension("spatial")
    engine.load_extension("spatial")
    engine.install_extension("ducklake")
    return (engine,)


@app.cell
def _(engine, mo):
    _ = mo.sql(
        f"""
        ATTACH 'ducklake:my_ducklake.ducklake' AS my_ducklake;
        USE my_ducklake;
        load spatial;

        -- error! ducklake does not surpport spatial yet.
        -- see: https://github.com/duckdb/ducklake/issues/32
        CREATE OR REPLACE TABLE points AS
        SELECT ST_Point(0,1)
        ;

        -- CREATE TABLE IF NOT EXISTS geo_data (
        --     date DATE,
        --     point_id INTEGER,
        --     min_temp INTEGER,
        --     max_temp INTEGER
        -- );

        -- ALTER TABLE geo_data SET PARTITIONED BY (year(date), month(date), day(date));
        """,
        engine=engine
    )
    return


@app.cell
def _():
    return


if __name__ == "__main__":
    app.run()
