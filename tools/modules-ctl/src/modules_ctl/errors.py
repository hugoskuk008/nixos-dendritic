"""Failures that modules-ctl reports to the user instead of crashing on."""

CLI_ERROR_PREFIX = "modules-ctl: "


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


class RepoNotFoundError(ModulesCtlError):
    """No flake root could be located from the working directory or --repo."""


class RebuildRefusedError(ModulesCtlError):
    """A rebuild was asked for that would reconfigure this machine with another host's configuration."""
