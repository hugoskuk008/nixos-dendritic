import tempfile
import unittest
from pathlib import Path

from modules_ctl.errors import InvalidSelectionError
from modules_ctl.model import ModuleKind
from modules_ctl.selection import KindSelection, Selection
from modules_ctl.selection_file import (
    load_selection,
    parse_selection,
    render_selection,
    save_selection,
)


class ParseSelectionTest(unittest.TestCase):
    def test_reads_both_kinds(self) -> None:
        selection = parse_selection(
            '{"nixos": {"enabled": ["a"], "disabled": ["b"]},'
            ' "homeManager": {"enabled": ["c"], "disabled": []}}'
        )
        self.assertEqual(selection.of_kind(ModuleKind.NIXOS), KindSelection(frozenset("a"), frozenset("b")))
        self.assertEqual(selection.of_kind(ModuleKind.HOME_MANAGER).enabled, frozenset("c"))

    def test_omitted_kinds_and_lists_mean_nothing_decided(self) -> None:
        self.assertEqual(parse_selection("{}"), Selection.empty())
        self.assertEqual(parse_selection('{"nixos": {"enabled": ["a"]}}').of_kind(ModuleKind.NIXOS).disabled, frozenset())

    def test_duplicates_are_tolerated(self) -> None:
        selection = parse_selection('{"nixos": {"enabled": ["a", "a"]}}')
        self.assertEqual(selection.of_kind(ModuleKind.NIXOS).enabled, frozenset("a"))

    def test_rejects_malformed_documents(self) -> None:
        malformed = {
            "not json": "{",
            "top level not an object": "[]",
            "unknown kind": '{"darwin": {}}',
            "unknown list": '{"nixos": {"maybe": []}}',
            "kind not an object": '{"nixos": []}',
            "names not a list": '{"nixos": {"enabled": "a"}}',
            "name not a string": '{"nixos": {"enabled": [1]}}',
            "enabled and disabled": '{"nixos": {"enabled": ["a"], "disabled": ["a"]}}',
        }
        for description, text in malformed.items():
            with self.subTest(description), self.assertRaises(InvalidSelectionError):
                parse_selection(text)

    def test_contradiction_names_the_kind_and_module(self) -> None:
        with self.assertRaisesRegex(InvalidSelectionError, "nixos.*both enabled and disabled: a"):
            parse_selection('{"nixos": {"enabled": ["a"], "disabled": ["a"]}}')


class RenderSelectionTest(unittest.TestCase):
    def test_output_is_sorted_complete_and_round_trips(self) -> None:
        selection = Selection.empty().with_kind(
            ModuleKind.NIXOS, KindSelection(frozenset({"b", "a"}), frozenset({"z"}))
        )
        text = render_selection(selection)
        self.assertLess(text.index('"a"'), text.index('"b"'))
        self.assertIn('"homeManager"', text)
        self.assertTrue(text.endswith("\n"))
        self.assertEqual(parse_selection(text), selection)


class SelectionFileTest(unittest.TestCase):
    def setUp(self) -> None:
        self._directory = tempfile.TemporaryDirectory()
        self.addCleanup(self._directory.cleanup)
        self.path = Path(self._directory.name) / "host" / "modules.json"

    def test_missing_file_means_nothing_decided(self) -> None:
        self.assertEqual(load_selection(self.path), Selection.empty())

    def test_save_then_load_round_trips_and_leaves_no_scratch_files(self) -> None:
        selection = Selection.empty().with_kind(ModuleKind.NIXOS, KindSelection(frozenset({"a"})))
        save_selection(self.path, selection)
        self.assertEqual(load_selection(self.path), selection)
        self.assertEqual([p.name for p in self.path.parent.iterdir()], ["modules.json"])

    def test_load_errors_name_the_file(self) -> None:
        self.path.parent.mkdir(parents=True)
        self.path.write_text("{")
        with self.assertRaisesRegex(InvalidSelectionError, "modules.json"):
            load_selection(self.path)


if __name__ == "__main__":
    unittest.main()
