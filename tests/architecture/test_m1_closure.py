from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"


class M1ClosureTests(unittest.TestCase):
    def text(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_every_decision_group_is_approved(self) -> None:
        decisions = self.text("docs/DECISIONS.md")
        headings = list(re.finditer(r"^## D(\d{2}) —", decisions, re.MULTILINE))
        self.assertEqual([int(match.group(1)) for match in headings], list(range(1, 20)))
        for index, heading in enumerate(headings):
            end = headings[index + 1].start() if index + 1 < len(headings) else len(decisions)
            section = decisions[heading.start():end]
            self.assertRegex(section, r"(?m)^- Status: APPROVED")
        self.assertIn("Status: APPROVED on 2026-09-21", decisions)

    def test_every_architecture_decision_is_selected(self) -> None:
        records = self.text("docs/decisions/ADRS.md")
        headings = list(re.finditer(r"^## ADR-(\d{2}) —", records, re.MULTILINE))
        self.assertEqual([int(match.group(1)) for match in headings], list(range(1, 16)))
        for index, heading in enumerate(headings):
            end = headings[index + 1].start() if index + 1 < len(headings) else len(records)
            section = records[heading.start():end]
            self.assertRegex(section, r"(?m)^- Selected option \(approved(?: replacement)?\):")

    def test_architecture_and_identity_are_frozen(self) -> None:
        architecture = self.text("docs/architecture/ARCHITECTURE.md")
        rules = self.text("docs/RULES.md")
        self.assertIn("Status: initial architecture accepted", architecture)
        self.assertIn("`m3-1` for the first complete headless-battle contract", rules)
        self.assertIn("`xoshiro128ss-1.1`", rules)
        self.assertNotIn("unassigned pre-release", rules)

    def test_checked_laws_have_matching_proofs(self) -> None:
        laws = self.text("LAWS.bend")
        proofs = self.text("PROOF.bend")
        law_names = set(re.findall(r"(?m)^law ([a-z0-9_]+):", laws))
        proof_names = set(re.findall(r"(?m)^def Laws\.([a-z0-9_]+)\(", proofs))
        self.assertTrue(law_names)
        self.assertEqual(proof_names, law_names)

    def test_candidate_law_catalog_covers_the_formal_domain(self) -> None:
        catalog = self.text("docs/LAW_CATALOG.md")
        required = {
            "DET-1", "VAL-1", "TIME-1", "CD-1", "MIX-1", "MIX-8",
            "LEARN-1", "LEARN-3", "HARM-1", "HARM-3", "DMG-1",
            "DMG-2", "HP-1", "INV-1", "PROG-1", "CAP-1", "REF-1",
            "EVENT-1", "SAVE-1", "REPLAY-1",
        }
        present = set(re.findall(r"^\| ([A-Z]+-\d+) \|", catalog, re.MULTILINE))
        self.assertTrue(required <= present, sorted(required - present))

    def test_local_markdown_links_resolve(self) -> None:
        failures: list[str] = []
        for source in sorted(DOCS.rglob("*.md")):
            text = source.read_text(encoding="utf-8")
            for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
                if "://" in target or target.startswith("#"):
                    continue
                path_text = target.split("#", 1)[0]
                if not path_text:
                    continue
                resolved = (source.parent / path_text).resolve()
                if not resolved.exists():
                    failures.append(f"{source.relative_to(ROOT)} -> {target}")
        self.assertEqual(failures, [])


if __name__ == "__main__":
    unittest.main()
