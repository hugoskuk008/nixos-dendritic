import unittest

from modules_ctl.errors import UnknownModuleError
from modules_ctl.model import ModuleKind, ModuleState, ModuleStatus
from modules_ctl.operations import disable_module, enable_module, forget_missing_modules
from modules_ctl.selection import KindSelection, Selection
from modules_ctl.status import collect_statuses
from tests.fakes import FakeRegistry

NIXOS, HOME_MANAGER = ModuleKind.NIXOS, ModuleKind.HOME_MANAGER


def selection_of(enabled=(), disabled=(), kind=NIXOS) -> Selection:
    return Selection.empty().with_kind(kind, KindSelection(frozenset(enabled), frozenset(disabled)))


class CollectStatusesTest(unittest.TestCase):
    def test_classifies_each_module_by_registration_and_decision(self) -> None:
        registry = FakeRegistry(nixos={"on", "off", "fresh"})
        selection = selection_of(enabled={"on", "gone"}, disabled={"off"})
        self.assertEqual(
            collect_statuses(selection, registry),
            [
                ModuleStatus(NIXOS, "fresh", ModuleState.NEW),
                ModuleStatus(NIXOS, "gone", ModuleState.MISSING),
                ModuleStatus(NIXOS, "off", ModuleState.DISABLED),
                ModuleStatus(NIXOS, "on", ModuleState.ENABLED),
            ],
        )

    def test_orders_nixos_before_home_manager_then_by_name(self) -> None:
        registry = FakeRegistry(nixos={"b"}, home_manager={"a"})
        kinds_and_names = [(s.kind, s.name) for s in collect_statuses(Selection.empty(), registry)]
        self.assertEqual(kinds_and_names, [(NIXOS, "b"), (HOME_MANAGER, "a")])

    def test_same_name_is_tracked_independently_per_kind(self) -> None:
        registry = FakeRegistry(nixos={"hyprland"}, home_manager={"hyprland"})
        selection = selection_of(enabled={"hyprland"})
        states = {s.kind: s.state for s in collect_statuses(selection, registry)}
        self.assertEqual(states, {NIXOS: ModuleState.ENABLED, HOME_MANAGER: ModuleState.NEW})


class EnableDisableTest(unittest.TestCase):
    registry = FakeRegistry(nixos={"a"})

    def test_enable_moves_a_module_out_of_disabled(self) -> None:
        result = enable_module(selection_of(disabled={"a"}), self.registry, NIXOS, "a")
        self.assertEqual(result.of_kind(NIXOS), KindSelection(enabled=frozenset({"a"})))

    def test_disable_moves_a_module_out_of_enabled(self) -> None:
        result = disable_module(selection_of(enabled={"a"}), self.registry, NIXOS, "a")
        self.assertEqual(result.of_kind(NIXOS), KindSelection(disabled=frozenset({"a"})))

    def test_deciding_on_a_new_module_clears_its_new_state(self) -> None:
        result = enable_module(Selection.empty(), self.registry, NIXOS, "a")
        (status,) = collect_statuses(result, self.registry)
        self.assertIs(status.state, ModuleState.ENABLED)

    def test_unregistered_names_are_rejected_and_the_input_is_untouched(self) -> None:
        original = selection_of()
        for operation in (enable_module, disable_module):
            with self.subTest(operation.__name__), self.assertRaisesRegex(UnknownModuleError, "'typo'.*registered: a"):
                operation(original, self.registry, NIXOS, "typo")
        self.assertEqual(original, selection_of())


class ForgetMissingModulesTest(unittest.TestCase):
    def test_removes_only_entries_the_flake_no_longer_registers(self) -> None:
        registry = FakeRegistry(nixos={"kept", "off"}, home_manager=set())
        selection = selection_of(enabled={"kept", "gone"}, disabled={"off", "old"})
        selection = selection.with_kind(HOME_MANAGER, KindSelection(frozenset({"stale"})))
        result = forget_missing_modules(selection, registry)
        self.assertEqual(result.of_kind(NIXOS), KindSelection(frozenset({"kept"}), frozenset({"off"})))
        self.assertEqual(result.of_kind(HOME_MANAGER), KindSelection())


if __name__ == "__main__":
    unittest.main()
