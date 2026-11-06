"""93 데이터 내보내기: the same content as a text file or a PDF."""

from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

TITLE = "YOUNIYA 기록 내보내기"
_FONTS = Path(__file__).parent / "fonts"


@dataclass
class StarEntry:
    title: str
    meta: str  # "2026년 11월 3일 21:30 · 평온 · 별빛 742"
    body: str


def as_text(stars: list[StarEntry], nebulae: list[str]) -> str:
    lines = [TITLE, ""]
    for s in stars:
        lines += [f"■ {s.title}", s.meta, "", s.body, ""]
    if nebulae:
        lines += ["", "성운", ""] + nebulae
    return "\n".join(lines)


def _register_fonts() -> None:
    if "NanumGothic" not in pdfmetrics.getRegisteredFontNames():
        pdfmetrics.registerFont(TTFont("NanumGothic", _FONTS / "NanumGothic-Regular.ttf"))
        pdfmetrics.registerFont(TTFont("NanumGothic-Bold", _FONTS / "NanumGothic-Bold.ttf"))


def _para(text: str) -> str:
    return escape(text).replace("\n", "<br/>")


def as_pdf(stars: list[StarEntry], nebulae: list[str]) -> bytes:
    _register_fonts()
    heading = ParagraphStyle("h", fontName="NanumGothic-Bold", fontSize=18, leading=26, spaceAfter=8 * mm)
    title = ParagraphStyle("t", fontName="NanumGothic-Bold", fontSize=13, leading=20)
    meta = ParagraphStyle("m", fontName="NanumGothic", fontSize=9, leading=14, textColor="#64748B", spaceAfter=3 * mm)
    body = ParagraphStyle("b", fontName="NanumGothic", fontSize=10.5, leading=18)

    story = [Paragraph(TITLE, heading)]
    for s in stars:
        story += [Paragraph(_para(s.title), title), Paragraph(_para(s.meta), meta),
                  Paragraph(_para(s.body), body), Spacer(1, 9 * mm)]
    if nebulae:
        story.append(Paragraph("성운", title))
        story += [Paragraph(_para(n), body) for n in nebulae]

    out = BytesIO()
    SimpleDocTemplate(out, pagesize=A4, title=TITLE, leftMargin=20 * mm, rightMargin=20 * mm,
                      topMargin=20 * mm, bottomMargin=20 * mm).build(story)
    return out.getvalue()
