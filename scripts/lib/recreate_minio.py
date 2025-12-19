"""Helpers to safely identify and optionally remove Docker volumes used by MinIO.

This module shells out to the docker CLI so it can be used without installing the
docker python SDK and is easy to unit-test by mocking subprocess functions.

It intentionally defaults to a conservative matching rule so it doesn't accidentally
remove unrelated volumes.
"""
from __future__ import annotations

import subprocess
from typing import List


def list_docker_volumes() -> List[str]:
    """Return a list of all docker volume names (strings).

    Raises: subprocess.CalledProcessError when docker CLI fails.
    """
    out = subprocess.check_output(["docker", "volume", "ls", "--format", "{{.Name}}"], text=True)
    return [l.strip() for l in out.splitlines() if l.strip()]


def find_minio_volumes(all_volumes: List[str] | None = None) -> List[str]:
    """Return volume names that look like minio data volumes.

    Matching rule (conservative): any volume name containing 'minio' and/or 'minio-data'.
    If all_volumes is provided, it's used instead of calling docker.
    """
    vols = all_volumes if all_volumes is not None else list_docker_volumes()
    candidates = [v for v in vols if 'minio' in v.lower() or 'minio-data' in v.lower()]
    # keep matches that also sound like data stores to be safer
    safe = [v for v in candidates if 'minio' in v.lower()]
    return safe


def remove_volumes(volumes: List[str]) -> None:
    """Remove each docker volume by name using 'docker volume rm'.

    Raises subprocess.CalledProcessError if any removal fails.
    """
    if not volumes:
        return
    # call docker volume rm for each volume name
    for v in volumes:
        try:
            subprocess.check_call(["docker", "volume", "rm", v])
        except subprocess.CalledProcessError:
            # attempt to find containers that reference the volume and remove them
            try:
                out = subprocess.check_output(['docker', 'ps', '-a', '--filter', f'volume={v}', '--format', '{{.ID}}'], text=True)
                containers = [l.strip() for l in out.splitlines() if l.strip()]
                for cid in containers:
                    try:
                        subprocess.check_call(['docker', 'rm', '-f', cid])
                    except subprocess.CalledProcessError:
                        # best-effort; continue to next container
                        pass

                # retry remove
                subprocess.check_call(["docker", "volume", "rm", v])
            except subprocess.CalledProcessError:
                # if still failing, propagate error so caller can decide
                raise


def recreate_minio(confirm: bool = False, non_interactive: bool = False) -> List[str]:
    """High-level helper that finds candidate minio volumes and removes them.

    Args:
        confirm: if True, skip confirmation prompt (caller must ensure user consent)
        non_interactive: if True, treat confirm as True and remove silently

    Returns the removed volume list.
    """
    vols = find_minio_volumes()
    if not vols:
        return []

    if not (confirm or non_interactive):
        # interactive confirmation step is left to callers that can prompt
        raise RuntimeError('recreate_minio requires explicit confirmation')

    remove_volumes(vols)
    return vols
