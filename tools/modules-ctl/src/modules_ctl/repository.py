"""Locating the dendritic repository and the hosts inside it."""

from pathlib import Path

from modules_ctl.errors import HostNotFoundError, RepoNotFoundError


def locate_repository(start: Path, fallback: Path) -> Path:
    """The nearest directory at or above `start` holding a flake.nix, else `fallback`.

    Launching from a menu starts in the home directory, outside the repository,
    which is why a fallback location is needed.
    """
    for directory in (start, *start.parents):
        if _is_flake_root(directory):
            return directory
    if _is_flake_root(fallback):
        return fallback
    raise RepoNotFoundError(
        f"no flake.nix in {start}, any parent directory, or {fallback}; "
        "run inside the repository or pass --repo"
    )


def list_hosts(repo: Path) -> list[str]:
    """Names of the directories under hosts/, alphabetical."""
    hosts_dir = repo / "hosts"
    if not hosts_dir.is_dir():
        return []
    return sorted(path.name for path in hosts_dir.iterdir() if path.is_dir())


def host_directory(repo: Path, host: str) -> Path:
    directory = repo / "hosts" / host
    if directory.is_dir():
        return directory
    if not (repo / "hosts").is_dir():
        raise HostNotFoundError(
            f"{repo} has no hosts/ directory; is this the right repository? (see --repo)"
        )
    available = ", ".join(list_hosts(repo)) or "none"
    raise HostNotFoundError(f"no host '{host}' under {repo / 'hosts'} (available: {available})")


def _is_flake_root(directory: Path) -> bool:
    return (directory / "flake.nix").is_file()
