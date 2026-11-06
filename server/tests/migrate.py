from pathlib import Path

from alembic import command
from alembic.config import Config

INI = Path(__file__).parent.parent / "alembic.ini"


def upgrade(url: str) -> None:
    cfg = Config(str(INI))
    cfg.attributes["url"] = url
    command.upgrade(cfg, "head")
