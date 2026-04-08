from __future__ import annotations
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, select_autoescape


class EmailTemplateService:
    """
    Load + render email templates from files under app/email_templates/.
    Simple in-memory cache prevents disk reads on every send.
    """

    def __init__(self, templates_dir: Path, cache_ttl_seconds: int = 60):
        self._templates_dir = templates_dir
        self._env = Environment(
            loader=FileSystemLoader(str(templates_dir)),
            autoescape=select_autoescape(enabled_extensions=("html", "xml")),
            auto_reload=True,
            cache_size=50,
        )

    def render(self, template_name: str, context: dict[str, Any]) -> str:
        # Cache rendered output *by template+context hash* is risky (user-specific).
        # Instead we cache the template object via Jinja's internal loader caching,
        # and optionally cache raw file contents by name for safety.
        tpl = self._env.get_template(template_name)
        return tpl.render(**context)


_TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "email_templates"
email_templates = EmailTemplateService(_TEMPLATES_DIR)

