import gzip
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

import maintain


class MaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.now = time.time()
        self.old = self.now - maintain.RETENTION - 100
        self.limit = patch.object(maintain, "LIMIT", 1024)
        self.limit.start()
        self.addCleanup(self.limit.stop)

    def put(self, relative, data=b"diagnostics", old=False):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        if old:
            os.utime(path, (self.old, self.old))
        return path

    def run_maintenance(self):
        maintain.maintain(self.home, self.now)

    def task(self, status="running", pid=-1):
        path = self.put(".pi/agent/async-bash/session/task.log", old=True)
        self.put(
            ".pi/agent/async-bash/session/tasks.json",
            json.dumps([{
                "id": "task", "status": status, "pid": pid,
                "endedAt": self.old * 1000,
                "logPath": "/do/not/trust/manifest/paths",
            }]).encode(),
        )
        return path

    def test_rotation_bounds_archives_and_keeps_open_inode(self):
        path = self.put("Library/Logs/sketchybar/sketchybar.out.log")
        inode = path.stat().st_ino
        with path.open("ab", buffering=0) as writer:
            for value in range(5):
                writer.write(bytes([value]) * 2048)
                self.run_maintenance()
                self.assertEqual(path.stat().st_size, 0)
                self.assertEqual(path.stat().st_ino, inode)
            writer.write(b"still logging")
        self.assertEqual(path.read_bytes(), b"still logging")
        for index, value in enumerate((4, 3, 2), 1):
            archive = Path(f"{path}.{index}.gz")
            self.assertEqual(gzip.decompress(archive.read_bytes()), bytes([value]) * 1024)
            self.assertEqual(archive.stat().st_mode & 0o777, 0o600)
        self.assertFalse(Path(f"{path}.4.gz").exists())
        self.assertFalse(Path(f"{path}.rotate-tmp").exists())

    def test_all_service_paths_and_missing_files(self):
        self.run_maintenance()
        for name in ("Library/Logs/agenix/stdout", "Library/Logs/agenix/stderr",
                     "Library/Logs/sketchybar/sketchybar.err.log",
                     ".local/state/dotfiles/wallpaper.log"):
            path = self.put(name, b"x" * 2048)
            self.run_maintenance()
            self.assertEqual(path.stat().st_size, 0)

    def test_active_bash_logs_rotate_but_never_expire(self):
        path = self.task()
        path.write_bytes(b"x" * 2048)
        os.utime(path, (self.old, self.old))
        self.run_maintenance()
        self.assertTrue(path.exists())
        self.assertTrue(Path(f"{path}.1.gz").exists())

    def test_completed_bash_logs_expire_with_archives_not_metadata(self):
        path = self.task("exited")
        archive = self.put(str(path.relative_to(self.home)) + ".1.gz", old=True)
        self.run_maintenance()
        self.assertFalse(path.exists())
        self.assertFalse(archive.exists())
        self.assertTrue((path.parent / "tasks.json").exists())

    def test_live_process_prevents_deletion_even_with_terminal_manifest(self):
        path = self.task("exited", os.getpid())
        self.run_maintenance()
        self.assertTrue(path.exists())

    def test_recent_output_and_unknown_state_are_preserved(self):
        path = self.task("exited")
        os.utime(path, None)
        self.run_maintenance()
        self.assertTrue(path.exists())
        path = self.task("unknown")
        self.run_maintenance()
        self.assertTrue(path.exists())

    def test_agent_requires_old_completion_evidence(self):
        prefix = ".pi/agent/agent-async/session/runtime/"
        active = self.put(prefix + "active.jsonl", old=True)
        completed = self.put(prefix + "done.jsonl", old=True)
        result = self.put(prefix + "done.result.txt", old=True)
        recent = self.put(prefix + "recent.result.txt")
        self.run_maintenance()
        self.assertTrue(active.exists())
        self.assertTrue(recent.exists())
        self.assertFalse(completed.exists())
        self.assertFalse(result.exists())

    def test_symlinks_and_hardlinks_are_not_modified(self):
        target = self.put("unrelated.log", b"x" * 2048)
        link = self.home / "Library/Logs/agenix/stdout"
        link.parent.mkdir(parents=True)
        link.symlink_to(target)
        os.link(target, link.parent / "stderr")
        self.run_maintenance()
        self.assertEqual(target.stat().st_size, 2048)
        link.unlink()
        (link.parent / "stderr").unlink()
        link.parent.rmdir()
        directory = self.home / "outside"
        directory.mkdir()
        outside = self.put("outside/stdout", b"x" * 2048)
        link.parent.symlink_to(directory, target_is_directory=True)
        self.run_maintenance()
        self.assertEqual(outside.stat().st_size, 2048)

    def test_corrupt_manifest_and_traversal_are_ignored(self):
        path = self.task("exited")
        manifest = path.parent / "tasks.json"
        for data in (b"{", b"{}", b'[{"id":"../task", "status":"exited"}]'):
            manifest.write_bytes(data)
            self.run_maintenance()
            self.assertTrue(path.exists())

    def test_conversations_are_never_touched(self):
        conversation = self.put(".pi/agent/sessions/session.jsonl", b"x" * 2048, old=True)
        self.run_maintenance()
        self.assertEqual(conversation.stat().st_size, 2048)


if __name__ == "__main__":
    unittest.main()
