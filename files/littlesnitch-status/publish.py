"""Publish only Little Snitch mode/filter preferences, never rules or traffic."""

import argparse
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import time

CLI = "/Applications/Little Snitch.app/Contents/Components/littlesnitch"
STATE_DIR = Path("/var/run/dotfiles-littlesnitch")


def probe(user):
    values = {}
    errors = []
    cli_disabled = False
    for key in ("activeSilentMode", "networkFilterEnabled"):
        try:
            result = subprocess.run(
                [CLI, "--user", user, "read-preference", key],
                capture_output=True,
                text=True,
                timeout=5,
                check=True,
            )
            value = json.loads(result.stdout)
            valid = (
                type(value) is int and value in (0, 1, 2)
                if key == "activeSilentMode"
                else type(value) is bool
            )
            if not valid:
                raise ValueError("unexpected preference value")
            values[key] = value
        except (OSError, subprocess.SubprocessError, ValueError) as error:
            # Recognize the CLI's authorization refusal, but never publish
            # arbitrary CLI output, paths, rules, or traffic.
            if isinstance(error, subprocess.CalledProcessError):
                output = ((error.stdout or "") + "\n" + (error.stderr or "")).lower()
                cli_disabled = cli_disabled or any(
                    marker in output
                    for marker in (
                        "command line tool is not authorized",
                        "please enable access in little snitch",
                        "allow access via terminal",
                    )
                )
            errors.append(key)
    return {
        "version": 1,
        "checked_at": int(time.time()),
        "mode": values.get("activeSilentMode"),
        "filter_enabled": values.get("networkFilterEnabled"),
        "error": "Could not read: " + ", ".join(errors) if errors else None,
        "error_kind": "cli_disabled" if cli_disabled else ("probe_failed" if errors else None),
    }


def publish(directory, status, owner_uid=0):
    directory = Path(directory)
    directory.mkdir(mode=0o755, exist_ok=True)
    info = directory.lstat()
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != owner_uid
        or info.st_mode & 0o022
    ):
        raise PermissionError("Status directory must be owned by the publisher and not writable by others")
    # Same-directory atomic replacement: readers never see partial JSON.
    fd, temporary = tempfile.mkstemp(prefix=".status-", dir=directory)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(status, stream)
            stream.write("\n")
            stream.flush()
            os.fchmod(stream.fileno(), 0o644)
        os.replace(temporary, directory / "status.json")
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--user", required=True)
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error("must run as root via the managed LaunchDaemon")
    os.umask(0o022)
    publish(STATE_DIR, probe(args.user))


if __name__ == "__main__":
    main()
