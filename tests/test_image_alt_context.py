"""Regression tests for decorative image alt-text classification."""

import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from analyze_images import image_alt_status  # noqa: E402
from parse_html import parse_html  # noqa: E402


def _parsed_image(markup: str) -> dict:
    return parse_html(f"<html><body>{markup}</body></html>")["images"][0]


def test_accessibility_hidden_card_thumbnail_is_decorative():
    image = _parsed_image(
        '<a href="/article/" tabindex="-1" aria-hidden="true">'
        '<img src="cover.webp" alt="">'
        '</a>'
    )
    assert image["decorative"] is True
    assert image_alt_status(image) == "decorative"


def test_presentation_role_with_empty_alt_is_decorative():
    image = _parsed_image('<img src="divider.svg" alt="" role="presentation">')
    assert image["decorative"] is True
    assert image_alt_status(image) == "decorative"


def test_unexplained_empty_alt_remains_weak():
    image = _parsed_image('<img src="product.webp" alt="">')
    assert image["decorative"] is False
    assert image_alt_status(image) == "weak"


def test_absent_alt_is_missing():
    image = _parsed_image('<img src="product.webp">')
    assert image_alt_status(image) == "missing"


def test_descriptive_alt_remains_descriptive():
    image = _parsed_image('<img src="product.webp" alt="Balatro Plasma Deck scoring example">')
    assert image_alt_status(image) == "descriptive"
