#!/usr/bin/env python3
from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys
import time
from dataclasses import dataclass

import requests
from bs4 import BeautifulSoup
from PIL import Image

try:
    import pillow_avif  # noqa: F401
except ImportError:
    pass

BASE_URL = "https://www.beyondallreason.info/units/{faction}-{slug}"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

CATEGORIES = {
    "Bots": "bots",
    "Vehicles": "vehicles",
    "Aircraft": "aircraft",
    "Ships": "ships",
    "Hovercraft": "hovercraft",
    "Factories": "factories",
    "Defense Buildings": "defense-buildings",
    "Buildings": "buildings",
}

FACTIONS = ("armada", "cortex")
FACTION_NAMES = {"armada": "Armada", "cortex": "Cortex"}
FACTION_PREFIX = {"armada": "arm", "cortex": "cor"}
CATEGORY_LABELS = {"Defense Buildings": "Defenses"}
LEGACY_CATEGORIES = {
    "_Bots",
    "_Vehicles",
    "_Aircraft",
    "_Ships",
    "_Hovercraft",
    "_Factories",
    "_Defenses",
    "_Defense Buildings",
    "_Buildings",
}

ENTRY_RE = re.compile(
    r"^(?P<name>.+?) - (?P<description>.+) - "
    r"(?P<tech>Tech Level \d+|Unknown Tech Level)\|(?P<command>/give .+)$"
)
GIVE_RE = re.compile(r"/give\s+\d+\s+(\w+)\s+\d+")
GRID_SELECTOR = 'div[data-w-tab="Grid"] > div.w-dyn-list > div.flex-unit-grid.w-dyn-items'


@dataclass
class Unit:
    code: str
    name: str
    description: str
    tech_level: str
    category: str
    command: str
    image_url: str = ""

    def to_line(self) -> str:
        return f"{self.name} - {self.description} - {self.tech_level}|{self.command}"

    def as_dict(self) -> dict:
        return {
            "code": self.code,
            "name": self.name,
            "description": self.description,
            "tech_level": self.tech_level,
            "category": self.category,
            "command": self.command,
        }


def dynamic_value(category: str, tech_level: str) -> int:
    return 1


class UnitScraper:
    def __init__(self, image_dir: str = "unit_images", timeout: int = 30, retries: int = 3):
        self.image_dir = image_dir
        self.timeout = timeout
        self.retries = retries
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENT})

    def get(self, url: str) -> requests.Response:
        last_error: Exception | None = None
        for attempt in range(1, self.retries + 1):
            try:
                response = self.session.get(url, timeout=self.timeout)
                response.raise_for_status()
                return response
            except requests.RequestException as exc:
                last_error = exc
                if attempt < self.retries:
                    time.sleep(0.5 * attempt)
        raise RuntimeError(f"GET {url} failed: {last_error}")

    def page_url(self, faction: str, category: str) -> str:
        return BASE_URL.format(faction=faction, slug=CATEGORIES[category])

    def get_tech_level(self, item) -> str:
        for level in range(1, 4):
            div = item.find("div", {"title": f"Tech Level {level}"}, class_="flex-unit-grid-tech")
            if div and "w-condition-invisible" not in div.get("class", []):
                return f"Tech Level {level}"
        return "Unknown Tech Level"

    def extract_unit(self, item, faction: str, category: str) -> Unit | None:
        link = item.find("a")
        href = link.get("href") if link else None
        if not href:
            return None
        code = href.rstrip("/").split("/")[-1]

        name_div = item.select_one("div.flex-unit-grid-text")
        desc_div = item.select_one("div.flex-unit-grid-text.unit-grid-text.sub")
        if not name_div or not desc_div:
            print(f"  warning: missing name/description for {code}", file=sys.stderr)
            return None

        name = name_div.get_text(strip=True)
        description = desc_div.get_text(strip=True)
        tech_level = self.get_tech_level(item)
        img = item.find("img", class_="flex-unit-grid-img")
        image_url = img.get("src", "") if img else ""
        command = f"/give {dynamic_value(category, tech_level)} {code} 0"
        return Unit(code, name, description, tech_level, category, command, image_url)

    def scrape_category(self, faction: str, category: str) -> list[Unit]:
        soup = BeautifulSoup(self.get(self.page_url(faction, category)).text, "html.parser")
        container = soup.select_one(GRID_SELECTOR)
        if not container:
            print(f"  warning: no unit grid for {faction} {category}", file=sys.stderr)
            return []
        units = []
        for item in container.find_all("div", class_="flex-unit-grid-item"):
            unit = self.extract_unit(item, faction, category)
            if unit:
                units.append(unit)
        return units

    def scrape_faction(self, faction: str, categories: list[str]) -> dict[str, list[Unit]]:
        results: dict[str, list[Unit]] = {}
        for category in categories:
            units = self.scrape_category(faction, category)
            results[category] = units
            print(f"  {faction} {category}: {len(units)} units")
        return results

    def download_images(self, units: list[Unit], force: bool = False) -> tuple[int, int]:
        os.makedirs(self.image_dir, exist_ok=True)
        downloaded = 0
        skipped = 0
        for unit in units:
            if not unit.image_url:
                continue
            path = os.path.join(self.image_dir, f"{unit.code}.png")
            if os.path.exists(path) and not force:
                skipped += 1
                continue
            try:
                response = self.get(unit.image_url)
                img = Image.open(io.BytesIO(response.content))
                if img.mode != "RGB":
                    img = img.convert("RGB")
                img = img.resize((256, 256), Image.Resampling.LANCZOS)
                img.save(path, "PNG")
                downloaded += 1
            except Exception as exc:
                print(f"  error image {unit.code}: {exc}", file=sys.stderr)
        return downloaded, skipped


def parse_unit_file(path: str) -> dict[str, dict[str, Unit]]:
    result: dict[str, dict[str, Unit]] = {}
    if not os.path.exists(path):
        return result
    category: str | None = None
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line:
                continue
            if "|" not in line and not raw.startswith((" ", "\t")):
                category = line.lstrip("_")
                result.setdefault(category, {})
                continue
            match = ENTRY_RE.match(line)
            if not match or category is None:
                continue
            command = match.group("command")
            give = GIVE_RE.search(command)
            if not give:
                continue
            code = give.group(1)
            result[category][code] = Unit(
                code=code,
                name=match.group("name"),
                description=match.group("description"),
                tech_level=match.group("tech"),
                category=category,
                command=command,
            )
    return result


def flatten(results: dict[str, dict[str, Unit]]) -> dict[str, Unit]:
    return {code: unit for units in results.values() for code, unit in units.items()}


def diff_units(
    faction: str,
    live: dict[str, list[Unit]],
    baseline: dict[str, dict[str, Unit]],
    image_dir: str,
) -> dict:
    live_flat = {u.code: u for units in live.values() for u in units}
    base_flat = flatten(baseline)
    common = sorted(set(live_flat) & set(base_flat))

    new = sorted((live_flat[c] for c in set(live_flat) - set(base_flat)), key=lambda u: u.code)
    removed = sorted((base_flat[c] for c in set(base_flat) - set(live_flat)), key=lambda u: u.code)

    changed = []
    moved = []
    for code in common:
        old, new_unit = base_flat[code], live_flat[code]
        fields = []
        for field in ("name", "description", "tech_level", "command"):
            if getattr(old, field) != getattr(new_unit, field):
                fields.append({"field": field, "old": getattr(old, field), "new": getattr(new_unit, field)})
        if old.category != new_unit.category:
            moved.append({"code": code, "old": old.category, "new": new_unit.category})
        if fields:
            changed.append({"code": code, "name": new_unit.name, "fields": fields})

    prefix = FACTION_PREFIX.get(faction, "")
    existing_images = {
        name[:-4]
        for name in os.listdir(image_dir)
        if name.endswith(".png") and name.startswith(prefix)
    } if os.path.isdir(image_dir) else set()
    missing_images = sorted(c for c in live_flat if c not in existing_images)
    orphan_images = sorted(existing_images - set(live_flat))

    return {
        "new": [u.as_dict() for u in new],
        "removed": [u.as_dict() for u in removed],
        "changed": changed,
        "moved": moved,
        "missing_images": missing_images,
        "orphan_images": orphan_images,
    }


def save_results(results: dict[str, list[Unit]], path: str) -> None:
    with open(path, "w", encoding="utf-8") as handle:
        for category, units in results.items():
            handle.write(f"_{category}\n")
            for unit in units:
                handle.write(f"    {unit.to_line()}\n")
            handle.write("\n")
    print(f"  wrote {path}")


def strip_legacy_categories(lines: list[str]) -> list[str]:
    output: list[str] = []
    skipping = False
    for line in lines:
        stripped = line.strip()
        if skipping:
            if stripped == "" or line.startswith((" ", "\t")):
                continue
            skipping = False
        if stripped in LEGACY_CATEGORIES:
            skipping = True
            continue
        output.append(line)
    return output


def merge_into(path: str, faction_results: dict[str, dict[str, list[Unit]]]) -> None:
    lines: list[str] = []
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().splitlines()

    managed = set(faction_results)
    output: list[str] = []
    skipping = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("; BEGIN bar-scraper "):
            faction = stripped.rsplit(" ", 1)[-1]
            skipping = faction in managed
            continue
        if stripped.startswith("; END bar-scraper "):
            skipping = False
            continue
        if not skipping:
            output.append(line)

    if "armada" in managed:
        output = strip_legacy_categories(output)

    while output and not output[-1].strip():
        output.pop()

    for faction, results in faction_results.items():
        title = FACTION_NAMES.get(faction, faction.title())
        output.append("")
        output.append(f"; BEGIN bar-scraper {faction}")
        for category, units in results.items():
            if not units:
                continue
            label = CATEGORY_LABELS.get(category, category)
            output.append(f"{title} {label}")
            for unit in units:
                output.append(f"    {unit.to_line()}")
        output.append(f"; END bar-scraper {faction}")

    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(output) + "\n")
    print(f"  merged {', '.join(managed)} into {path}")


def print_diff(faction: str, report: dict) -> None:
    print(f"\n=== {FACTION_NAMES.get(faction, faction)} vs baseline ===")
    print(f"  new:            {len(report['new'])}")
    print(f"  removed:        {len(report['removed'])}")
    print(f"  changed:        {len(report['changed'])}")
    print(f"  moved category: {len(report['moved'])}")
    print(f"  missing images: {len(report['missing_images'])}")
    print(f"  orphan images:  {len(report['orphan_images'])}")

    for unit in report["new"]:
        print(f"  + {unit['code']:16s} {unit['name']} - {unit['description']} [{unit['tech_level']}]")
    for unit in report["removed"]:
        print(f"  - {unit['code']:16s} {unit['name']} - {unit['description']} [{unit['tech_level']}]")
    for entry in report["changed"]:
        print(f"  ~ {entry['code']:16s} {entry['name']}")
        for change in entry["fields"]:
            print(f"      {change['field']}: {change['old']!r} -> {change['new']!r}")
    for entry in report["moved"]:
        print(f"  > {entry['code']:16s} {entry['old']} -> {entry['new']}")
    if report["missing_images"]:
        print(f"  missing images: {', '.join(report['missing_images'])}")
    if report["orphan_images"]:
        print(f"  orphan images:  {', '.join(report['orphan_images'])}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Scrape BAR unit data and preview images from beyondallreason.info")
    parser.add_argument("--faction", choices=[*FACTIONS, "all"], default="all", help="faction(s) to scrape")
    parser.add_argument("--category", action="append", choices=list(CATEGORIES), help="limit to one or more categories")
    parser.add_argument("--check", action="store_true", help="dry run: report differences, write/download nothing")
    parser.add_argument("--baseline", help="baseline file to diff against (single faction only)")
    parser.add_argument("--no-images", action="store_true", help="do not download preview images")
    parser.add_argument("--refresh-images", action="store_true", help="re-download images that already exist")
    parser.add_argument("--image-dir", default="unit_images", help="image output directory")
    parser.add_argument("--output-dir", default=".", help="directory for bar_units_<faction>.txt files")
    parser.add_argument("--merge", help="merge results into this cheat file (e.g. bar_cheats.txt)")
    parser.add_argument("--json", action="store_true", help="print the check report as JSON")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    factions = list(FACTIONS) if args.faction == "all" else [args.faction]
    categories = args.category or list(CATEGORIES)

    if args.baseline and len(factions) != 1:
        print("error: --baseline requires a single --faction", file=sys.stderr)
        return 2

    scraper = UnitScraper(image_dir=args.image_dir)
    all_results: dict[str, dict[str, list[Unit]]] = {}

    print(f"Scraping {', '.join(factions)}...")
    for faction in factions:
        all_results[faction] = scraper.scrape_faction(faction, categories)

    if args.check:
        report: dict[str, dict] = {}
        drift = False
        for faction in factions:
            baseline_path = args.baseline or os.path.join(args.output_dir, f"bar_units_{faction}.txt")
            baseline = parse_unit_file(baseline_path)
            faction_report = diff_units(faction, all_results[faction], baseline, args.image_dir)
            report[faction] = faction_report
            if any(faction_report[key] for key in ("new", "removed", "changed", "moved", "missing_images", "orphan_images")):
                drift = True
            if not args.json:
                print_diff(faction, faction_report)
        if args.json:
            print(json.dumps(report, indent=2))
        return 1 if drift else 0

    for faction in factions:
        results = all_results[faction]
        output_path = os.path.join(args.output_dir, f"bar_units_{faction}.txt")
        save_results(results, output_path)
        if not args.no_images:
            units = [u for units in results.values() for u in units]
            downloaded, skipped = scraper.download_images(units, force=args.refresh_images)
            print(f"  {faction} images: {downloaded} downloaded, {skipped} already present")

    if args.merge:
        merge_into(args.merge, all_results)

    print("\nFinal Results Summary:")
    for faction, results in all_results.items():
        total = sum(len(units) for units in results.values())
        print(f"  {faction}: {total} units")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
