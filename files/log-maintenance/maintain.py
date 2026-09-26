"""Hourly maintenance of explicitly allowlisted dotfiles logs (no conversation history)."""

import argparse
import fcntl
import gzip
import json
import os
from pathlib import Path
import re
import stat
import time

LIMIT = 10 * 1024 * 1024
RETENTION = 30 * 86400
ARCHIVES = 3
TASK_ID = re.compile(r"[A-Za-z0-9_-]+\Z")


def regular(path):
    try:
        info = path.lstat()
        return (
            stat.S_ISREG(info.st_mode)
            and info.st_uid == os.getuid()
            and info.st_nlink == 1
        )
    except FileNotFoundError:
        return False


def directories(path):
    if path.is_symlink() or not path.is_dir():
        return []
    return [p for p in path.iterdir() if not p.is_symlink() and p.is_dir()]


def safe_parent(path, home):
    # Never follow a symlink in the allowlisted path, including intermediate dirs.
    current = path
    while current != home:
        if current.is_symlink():
            return False
        current = current.parent
    return not home.is_symlink()


def rotate(path):
    if not regular(path) or path.stat().st_size <= LIMIT:
        return
    archives = [Path(f"{path}.{i}.gz") for i in range(1, ARCHIVES + 1)]
    temporary = Path(f"{path}.rotate-tmp")
    if temporary.exists() or temporary.is_symlink():
        if not regular(temporary):
            return
        # A previous run may have been interrupted before the atomic rename.
        # The job-wide lock prevents overlap with another maintenance run.
        temporary.unlink()
    if any((p.exists() or p.is_symlink()) and not regular(p) for p in archives):
        return
    fd = os.open(path, os.O_RDWR | os.O_NOFOLLOW)
    try:
        with os.fdopen(fd, "r+b") as source:
            info = os.fstat(source.fileno())
            if info.st_ino != path.lstat().st_ino or info.st_nlink != 1:
                return
            # Bound archive size/work even after a very large error flood. Retain
            # the most recent 10 MiB, not gigabytes of repeated diagnostics.
            source.seek(max(0, info.st_size - LIMIT))
            snapshot = source.read(LIMIT)
            archive_fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(archive_fd, "wb") as output:
                with gzip.GzipFile(fileobj=output, mode="wb", mtime=0) as compressed:
                    compressed.write(snapshot)
            for previous, following in reversed(list(zip(archives, archives[1:]))):
                if previous.exists():
                    previous.replace(following)
            temporary.replace(archives[0])
            # Keep the inode: launchd and shell children hold open append fds.
            # Copy/truncate can lose bytes written during this operation.
            source.truncate(0)
    finally:
        if temporary.exists() and regular(temporary):
            temporary.unlink()


def remove_log(path):
    for candidate in [path, *(Path(f"{path}.{i}.gz") for i in range(1, ARCHIVES + 1))]:
        if regular(candidate):
            candidate.unlink()


def process_alive(pid):
    if not isinstance(pid, int) or pid <= 0:
        return False
    # Preserve logs if either the original PID or its detached process group
    # still exists. Reused PIDs are conservative false positives, not deletions.
    for target in (pid, -pid):
        try:
            os.kill(target, 0)
            return True
        except ProcessLookupError:
            pass
        except PermissionError:
            return True
    return False


def maintain(home, now=None):
    now = time.time() if now is None else now
    cutoff = now - RETENTION
    service_logs = [
        "Library/Logs/sketchybar/sketchybar.out.log",
        "Library/Logs/sketchybar/sketchybar.err.log",
        "Library/Logs/agenix/stdout",
        "Library/Logs/agenix/stderr",
        ".local/state/dotfiles/wallpaper.log",
    ]
    for relative in service_logs:
        path = home / relative
        if safe_parent(path, home):
            rotate(path)

    bash_root = home / ".pi/agent/async-bash"
    if safe_parent(bash_root, home):
        for session in directories(bash_root):
            manifest = session / "tasks.json"
            if not regular(manifest) or manifest.stat().st_size > LIMIT:
                continue
            try:
                tasks = json.loads(manifest.read_text())
            except (ValueError, OSError):
                continue  # Includes a concurrent, non-atomic manifest write.
            if not isinstance(tasks, list):
                continue
            for task in tasks:
                if not isinstance(task, dict) or not TASK_ID.fullmatch(str(task.get("id", ""))):
                    continue
                path = session / f"{task['id']}.log"
                ended = task.get("endedAt")
                expired = (
                    task.get("status") in ("exited", "killed")
                    and isinstance(ended, (int, float))
                    and 0 < ended / 1000 < cutoff
                    and not process_alive(task.get("pid"))
                    and (not regular(path) or path.stat().st_mtime < cutoff)
                )
                if expired:
                    remove_log(path)
                else:
                    rotate(path)
            # Keep the manifest: restored sessions still need their task metadata.

    agent_root = home / ".pi/agent/agent-async"
    if safe_parent(agent_root, home):
        for session in directories(agent_root):
            for runtime in directories(session):
                # Result files are written only upon completion/cancellation.
                # Missing completion evidence means preserve the transcript,
                # even when old (a blocked task may be silent indefinitely).
                for result in runtime.glob("*.result.txt"):
                    task_id = result.name.removesuffix(".result.txt")
                    transcript = runtime / f"{task_id}.jsonl"
                    if (
                        TASK_ID.fullmatch(task_id)
                        and regular(result)
                        and result.stat().st_mtime < cutoff
                        and (not transcript.exists() or (
                            regular(transcript) and transcript.stat().st_mtime < cutoff
                        ))
                    ):
                        remove_log(transcript)
                        result.unlink()
                # Remove only empty directories, never recursive deletion.
                try:
                    runtime.rmdir()
                except OSError:
                    pass
            try:
                session.rmdir()
            except OSError:
                pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, required=True)
    args = parser.parse_args()
    state = args.home / ".local/state/dotfiles"
    if not safe_parent(state, args.home):
        raise SystemExit("Refusing symlinked maintenance state directory")
    state.mkdir(parents=True, exist_ok=True)
    fd = os.open(state / "log-maintenance.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        maintain(args.home)


if __name__ == "__main__":
    main()
