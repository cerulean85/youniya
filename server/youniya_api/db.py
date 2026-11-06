"""Engine setup shared by the server and the migrations."""

from sqlalchemy import Engine, create_engine, event


def normalize_url(url: str) -> str:
    """`postgresql://` (as Neon and most hosts give it) uses psycopg 3."""
    if url.startswith("postgresql://") or url.startswith("postgres://"):
        return "postgresql+psycopg://" + url.split("://", 1)[1]
    return url


def make_engine(url: str) -> Engine:
    url = normalize_url(url)
    if url.startswith("sqlite"):
        engine = create_engine(url, connect_args={"check_same_thread": False})
        event.listen(engine, "connect", lambda conn, _: conn.execute("PRAGMA foreign_keys=ON"))
        return engine
    # Behind a transaction pooler (Neon, PgBouncer) server-side prepared statements can't be
    # reused across connections, and idle connections get dropped: no prepares, ping first.
    return create_engine(url, pool_pre_ping=True, connect_args={"prepare_threshold": None})
