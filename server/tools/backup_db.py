"""Database backup without pg_dump: every table as CSV from one consistent snapshot.

    python tools/backup_db.py dump  DATABASE_URL DIR [--keep 14]   → DIR/youniya-YYYYMMDD-HHMMSS.tar.gz
    python tools/backup_db.py check DATABASE_URL ARCHIVE           → restores into a scratch schema, compares, drops it
    python tools/backup_db.py restore DATABASE_URL ARCHIVE         → into an empty database at the same migration

The schema is not in the archive: it comes from the migrations (`alembic upgrade head` on the
new database, to the revision in meta.json), then restore copies the rows in. Writing stays
encrypted as it is in the database, so a restore is only readable with the same
DATA_ENCRYPTION_KEY. rate_hits is skipped: it only holds the last day's request counts."""

import argparse
import io
import json
import os
import sys
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from psycopg import sql

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api.models import Base  # noqa: E402

SKIP = {"rate_hits"}
TABLES = [t for t in Base.metadata.sorted_tables if t.name not in SKIP]  # parents before children


def _url(url: str) -> str:
    return url.replace("postgresql+psycopg://", "postgresql://", 1)


def dump(url: str, out_dir: Path, keep: int) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    os.chmod(out_dir, 0o700)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    target = out_dir / f"youniya-{stamp}.tar.gz"
    meta = {"created_at": stamp, "tables": {}}
    with psycopg.connect(_url(url)) as conn, tempfile.TemporaryDirectory() as tmp:
        conn.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY")
        meta["revision"] = conn.execute("SELECT version_num FROM alembic_version").fetchone()[0]
        for t in TABLES:
            cols = [c.name for c in t.columns]
            path = Path(tmp) / f"{t.name}.csv"
            with path.open("wb") as f:
                f.write(_export(conn, t, cols, None))
            rows = conn.execute(sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier(t.name))).fetchone()[0]
            meta["tables"][t.name] = {"rows": rows, "columns": cols}
        (Path(tmp) / "meta.json").write_text(json.dumps(meta, indent=1))
        partial = target.with_suffix(".partial")
        fd = os.open(partial, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "wb") as raw, tarfile.open(fileobj=raw, mode="w:gz") as tar:
            for name in ["meta.json"] + [f"{t.name}.csv" for t in TABLES]:
                tar.add(Path(tmp) / name, arcname=name)
        partial.rename(target)
    for old in sorted(out_dir.glob("youniya-*.tar.gz"))[:-keep]:
        old.unlink()
    total = sum(v["rows"] for v in meta["tables"].values())
    print(f"{target} · revision {meta['revision']} · {total} rows")
    return target


def _export(conn, t, cols: list[str], schema: str | None) -> bytes:
    """The table as CSV, ordered by its key so the same rows always give the same bytes."""
    table = sql.Identifier(schema, t.name) if schema else sql.Identifier(t.name)
    order = [c.name for c in t.primary_key.columns] or cols
    query = sql.SQL("COPY (SELECT {} FROM {} ORDER BY {}) TO STDOUT WITH (FORMAT csv, HEADER)").format(
        sql.SQL(", ").join(map(sql.Identifier, cols)), table, sql.SQL(", ").join(map(sql.Identifier, order)))
    buf = io.BytesIO()
    with conn.cursor().copy(query) as copy:
        for chunk in copy:
            buf.write(chunk)
    return buf.getvalue()


def _load(archive: Path):
    tar = tarfile.open(archive, "r:gz")
    meta = json.loads(tar.extractfile("meta.json").read())
    return tar, meta


def _copy_in(conn, tar, meta, schema: str | None) -> dict:
    counts = {}
    for t in TABLES:
        cols = meta["tables"][t.name]["columns"]
        table = sql.Identifier(schema, t.name) if schema else sql.Identifier(t.name)
        query = sql.SQL("COPY {} ({}) FROM STDIN WITH (FORMAT csv, HEADER)").format(
            table, sql.SQL(", ").join(map(sql.Identifier, cols)))
        data = tar.extractfile(f"{t.name}.csv")
        with conn.cursor().copy(query) as copy:
            while chunk := data.read(1 << 16):
                copy.write(chunk)
        counts[t.name] = conn.execute(sql.SQL("SELECT count(*) FROM {}").format(table)).fetchone()[0]
        # Integer ids carry on after the restored rows.
        for c in t.primary_key.columns:
            if c.autoincrement is True or (c.autoincrement == "auto" and c.type.python_type is int):
                qualified = f"{schema}.{t.name}" if schema else t.name
                conn.execute(sql.SQL("SELECT setval(pg_get_serial_sequence(%s, %s), "
                                     "coalesce((SELECT max({c}) FROM {t}), 1), "
                                     "(SELECT max({c}) FROM {t}) IS NOT NULL)").format(c=sql.Identifier(c.name),
                                                                                     t=table),
                             (qualified, c.name))
    return counts


def restore(url: str, archive: Path) -> None:
    tar, meta = _load(archive)
    with psycopg.connect(_url(url)) as conn:
        revision = conn.execute("SELECT version_num FROM alembic_version").fetchone()[0]
        if revision != meta["revision"]:
            sys.exit(f"the database is at {revision}; run `alembic upgrade {meta['revision']}` on an empty one first")
        busy = [t.name for t in TABLES
                if conn.execute(sql.SQL("SELECT EXISTS (SELECT 1 FROM {})").format(sql.Identifier(t.name))).fetchone()[0]]
        if busy:
            sys.exit(f"refusing to restore over existing rows in: {', '.join(busy)}")
        counts = _copy_in(conn, tar, meta, None)
    _compare(meta, counts)


def check(url: str, archive: Path) -> None:
    """Restores into a scratch schema of this database, compares every row, then drops the schema."""
    from sqlalchemy import create_engine

    from youniya_api.db import normalize_url

    tar, meta = _load(archive)
    schema = "restore_check_" + meta["created_at"].replace("-", "_")
    engine = create_engine(normalize_url(url), connect_args={"prepare_threshold": None})
    try:
        with engine.begin() as c:
            c.exec_driver_sql(f'CREATE SCHEMA "{schema}"')
        Base.metadata.create_all(engine.execution_options(schema_translate_map={None: schema}),
                                 tables=[t for t in Base.metadata.sorted_tables])
        with psycopg.connect(_url(url)) as conn:
            counts = _copy_in(conn, tar, meta, schema)
            # Byte for byte: what comes back out is what went into the archive.
            differ = [t.name for t in TABLES
                      if _export(conn, t, meta["tables"][t.name]["columns"], schema)
                      != tar.extractfile(f"{t.name}.csv").read()]
            conn.rollback()  # nothing kept even before the schema goes
        if differ:
            sys.exit(f"restored rows differ from the archive in: {', '.join(differ)}")
        _compare(meta, counts)
    finally:
        with engine.begin() as c:
            c.exec_driver_sql(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE')


def _compare(meta: dict, counts: dict) -> None:
    wrong = {k: (v["rows"], counts.get(k)) for k, v in meta["tables"].items() if counts.get(k) != v["rows"]}
    if wrong:
        sys.exit(f"row counts differ (archive, restored): {wrong}")
    print(f"restored {sum(counts.values())} rows in {len(counts)} tables · revision {meta['revision']} · ok")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["dump", "check", "restore"])
    ap.add_argument("url")
    ap.add_argument("path", type=Path)
    ap.add_argument("--keep", type=int, default=14)
    a = ap.parse_args()
    if a.action == "dump":
        dump(a.url, a.path, a.keep)
    elif a.action == "check":
        check(a.url, a.path)
    else:
        restore(a.url, a.path)


if __name__ == "__main__":
    from youniya_api.monitoring import init_sentry

    # A backup that fails at 04:00 should not go unnoticed (same scrubbing as the server).
    if init_sentry(os.getenv("SENTRY_DSN"), "backup"):
        import sentry_sdk

        try:
            main()
        except Exception as e:
            sentry_sdk.capture_exception(e)
            sentry_sdk.flush(10)
            raise
    else:
        main()
