from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext

from youniya_api.db import make_engine
from youniya_api.models import Base

from .migrate import upgrade


def test_migrations_match_the_models(tmp_path):
    url = f"sqlite:///{tmp_path}/m.db"
    upgrade(url)
    engine = make_engine(url)
    with engine.connect() as conn:
        diff = compare_metadata(MigrationContext.configure(conn), Base.metadata)
    assert diff == [], f"models changed without a migration: {diff}"


def test_postgres_urls_use_psycopg():
    from youniya_api.db import normalize_url

    assert normalize_url("postgresql://u:p@h/db?sslmode=require").startswith("postgresql+psycopg://u:p@h/db")
    assert normalize_url("sqlite:///x.db") == "sqlite:///x.db"
