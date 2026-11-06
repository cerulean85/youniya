from alembic import context

from youniya_api.config import Settings
from youniya_api.db import make_engine
from youniya_api.models import Base

config = context.config
# Tests pass the URL in; otherwise it is DATABASE_URL, as for the server.
url = config.attributes.get("url") or Settings().database_url

engine = make_engine(url)
with engine.connect() as connection:
    # Batch mode lets ALTERs work on SQLite (tests and local runs) as well as Postgres.
    context.configure(connection=connection, target_metadata=Base.metadata, render_as_batch=True,
                      compare_type=True)
    with context.begin_transaction():
        context.run_migrations()
engine.dispose()
