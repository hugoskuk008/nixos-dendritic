import unittest

from modules_ctl.gui.model import ModuleCommand, ModuleListModel, matches_search, preferred_host
from modules_ctl.model import ModuleKind, ModuleState, ModuleStatus

NIXOS, HOME_MANAGER = ModuleKind.NIXOS, ModuleKind.HOME_MANAGER
ENABLED, DISABLED, NEW, MISSING = (
    ModuleState.ENABLED, ModuleState.DISABLED, ModuleState.NEW, ModuleState.MISSING,
)

ON = ModuleStatus(NIXOS, "on", ENABLED)
OFF = ModuleStatus(NIXOS, "off", DISABLED)
FRESH = ModuleStatus(NIXOS, "fresh", NEW)
GONE = ModuleStatus(HOME_MANAGER, "gone", MISSING)


class ModuleListModelTest(unittest.TestCase):
    def setUp(self) -> None:
        self.model = ModuleListModel([ON, OFF, FRESH, GONE])

    def test_nothing_is_pending_until_the_user_chooses(self) -> None:
        self.assertEqual(self.model.pending_commands(), [])
        self.assertEqual(self.model.shown_state(FRESH), NEW)

    def test_choices_become_commands_in_list_order(self) -> None:
        self.model.decide(FRESH, ENABLED)
        self.model.decide(ON, DISABLED)
        self.assertEqual(
            self.model.pending_commands(),
            [ModuleCommand.disable(NIXOS, "on"), ModuleCommand.enable(NIXOS, "fresh")],
        )

    def test_a_new_module_can_be_decided_either_way(self) -> None:
        self.model.decide(FRESH, DISABLED)
        self.assertEqual(self.model.pending_commands(), [ModuleCommand.disable(NIXOS, "fresh")])

    def test_choosing_the_saved_state_again_withdraws_the_change(self) -> None:
        self.model.decide(ON, DISABLED)
        self.model.decide(ON, ENABLED)
        self.assertEqual(self.model.pending_commands(), [])
        self.assertFalse(self.model.is_changed(ON))

    def test_shown_state_and_changed_flag_follow_the_choice(self) -> None:
        self.model.decide(OFF, ENABLED)
        self.assertEqual(self.model.shown_state(OFF), ENABLED)
        self.assertTrue(self.model.is_changed(OFF))
        self.assertFalse(self.model.is_changed(ON))

    def test_missing_modules_cannot_be_decided(self) -> None:
        with self.assertRaisesRegex(ValueError, "prune"):
            self.model.decide(GONE, ENABLED)

    def test_only_enabled_or_disabled_are_decisions(self) -> None:
        with self.assertRaises(ValueError):
            self.model.decide(ON, NEW)

    def test_pruning_adds_one_final_command_only_when_something_is_missing(self) -> None:
        self.model.decide(FRESH, ENABLED)
        self.model.prune_missing = True
        self.assertEqual(self.model.pending_commands()[-1], ModuleCommand.prune())
        self.assertEqual(self.model.missing_count, 1)

        nothing_missing = ModuleListModel([ON])
        nothing_missing.prune_missing = True
        self.assertEqual(nothing_missing.pending_commands(), [])

    def test_discarding_clears_choices_and_the_prune_request(self) -> None:
        self.model.decide(ON, DISABLED)
        self.model.prune_missing = True
        self.model.discard_changes()
        self.assertEqual(self.model.pending_commands(), [])

    def test_same_name_in_two_kinds_is_decided_independently(self) -> None:
        nixos = ModuleStatus(NIXOS, "hyprland", ENABLED)
        home = ModuleStatus(HOME_MANAGER, "hyprland", NEW)
        model = ModuleListModel([nixos, home])
        model.decide(home, ENABLED)
        self.assertEqual(model.pending_commands(), [ModuleCommand.enable(HOME_MANAGER, "hyprland")])


class MatchesSearchTest(unittest.TestCase):
    status = ModuleStatus(NIXOS, "hyprland", ENABLED)

    def test_an_empty_query_matches_everything(self) -> None:
        self.assertTrue(matches_search(self.status, ""))
        self.assertTrue(matches_search(self.status, "   "))

    def test_matches_name_kind_or_state_case_insensitively(self) -> None:
        for query in ("hypr", "HYPRLAND", "nixos", "enabled"):
            with self.subTest(query):
                self.assertTrue(matches_search(self.status, query))

    def test_every_word_must_match(self) -> None:
        self.assertTrue(matches_search(self.status, "nixos hypr"))
        self.assertFalse(matches_search(self.status, "nixos waybar"))
        self.assertFalse(matches_search(self.status, "disabled hypr"))


class PreferredHostTest(unittest.TestCase):
    def test_own_hostname_wins_then_first_then_none(self) -> None:
        self.assertEqual(preferred_host(["laptop", "box"], "box"), "box")
        self.assertEqual(preferred_host(["laptop", "box"], "other"), "laptop")
        self.assertIsNone(preferred_host([], "box"))


if __name__ == "__main__":
    unittest.main()
