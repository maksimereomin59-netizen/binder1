"""Fast, platform-independent checks for the MedBind source layout and bundle."""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build  # noqa: E402  (tools is intentionally a small standalone script)


class ProjectLayoutTests(unittest.TestCase):
    def test_every_source_module_exists_once(self) -> None:
        paths = [relative_path for _, relative_path in build.MODULES]
        self.assertEqual(len(paths), len(set(paths)), "duplicate module path in build manifest")
        for relative_path in paths:
            with self.subTest(module=relative_path):
                self.assertTrue((ROOT / relative_path).is_file(), f"missing {relative_path}")

    def test_modules_are_grouped_by_concern(self) -> None:
        for _, relative_path in build.MODULES:
            with self.subTest(module=relative_path):
                parent = Path(relative_path).parent.as_posix()
                self.assertIn(parent, {"src/core", "src/ui"})

    def test_launcher_is_currently_built_from_sources(self) -> None:
        self.assertTrue(build.OUTPUT.is_file(), "DoctorBinder.ahk is missing")
        self.assertEqual(
            build.OUTPUT.read_bytes(),
            build.bundle_bytes(),
            "DoctorBinder.ahk is out of date; run: python tools/build.py",
        )

    def test_bundle_has_each_module_once_in_manifest_order(self) -> None:
        bundle = build.render_bundle()
        positions = []
        for name, _ in build.MODULES:
            marker = f"; ==================== {name} ===================="
            with self.subTest(module=name):
                self.assertEqual(bundle.count(marker), 1)
                positions.append(bundle.index(marker))
        self.assertEqual(positions, sorted(positions))

    def test_bundle_targets_autohotkey_v2_and_has_startup(self) -> None:
        bundle = build.render_bundle().lstrip("\ufeff")
        self.assertTrue(bundle.startswith("#Requires AutoHotkey v2.0\n"))
        self.assertIn("    Theme.Init()\n    Store.Load()\n    Keys.Apply()\n    MainUI.Show()", bundle)

    def test_reserved_in_keyword_is_not_used_as_variable(self) -> None:
        bundle = build.render_bundle()
        self.assertNotRegex(bundle, r"(?m)\b(?:try\s+)?in\s*:=")

    def test_all_icon_references_are_defined(self) -> None:
        bundle = build.render_bundle()
        theme = build.read_ahk_source("src/ui/Theme.ahk")
        icon_class = re.search(r"(?ms)^class Icon\s*\{(.*?)^\}", theme)
        self.assertIsNotNone(icon_class, "Icon class is missing")
        defined = set(re.findall(r"(?m)^\s*static\s+(\w+)\s*(?::=|\()", icon_class.group(1)))
        referenced = set(re.findall(r"\bIcon\.(\w+)", bundle))
        self.assertFalse(referenced - defined, f"undefined icons: {sorted(referenced - defined)}")

    def test_bind_cards_and_inspector_do_not_add_text_only_panels(self) -> None:
        main_ui = build.read_ahk_source("src/ui/MainUI.ahk")
        self.assertNotIn("catb :=", main_ui)
        self.assertNotIn("d.catb", main_ui)
        self.assertNotIn("d.dfr", main_ui)
        self.assertIn("card.selBar", main_ui)
        self.assertIn("d.meta :=", main_ui)

    def test_inspector_keeps_single_multi_and_empty_states(self) -> None:
        main_ui = build.read_ahk_source("src/ui/MainUI.ahk")
        self.assertIn("Preview.Chat(b)", main_ui)
        self.assertIn("Preview.List(ids)", main_ui)
        self.assertIn("d.emptyTitle", main_ui)
        self.assertIn("this.PgInfo.Move(infoX", main_ui)


if __name__ == "__main__":
    unittest.main()
