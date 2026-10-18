"""Failures that modules-ctl reports to the user instead of crashing on."""


class ModulesCtlError(Exception):
    """Base class: the CLI prints these as one-line messages and exits non-zero."""


class InvalidSelectionError(ModulesCtlError):
    """A host's modules.json is malformed or contradicts itself."""


class UnknownModuleError(ModulesCtlError):
    """The requested module is not registered by the flake."""


class RegistryError(ModulesCtlError):
    """The flake could not be asked which modules it registers."""


class HostNotFoundError(ModulesCtlError):
    """No directory exists under hosts/ for the requested host."""
