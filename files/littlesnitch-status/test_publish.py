import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import publish


class PublisherTests(unittest.TestCase):
    def probe(self, mode="0", enabled="true"):
        results = [
            subprocess.CompletedProcess([], 0, mode),
            subprocess.CompletedProcess([], 0, enabled),
        ]
        with patch.object(publish.subprocess, "run", side_effect=results) as run:
            result = publish.probe("taglia")
        self.assertEqual(run.call_count, 2)
        for call in run.call_args_list:
            self.assertEqual(call.args[0][:3], [publish.CLI, "--user", "taglia"])
            self.assertEqual(call.args[0][3], "read-preference")
            self.assertEqual(call.kwargs["timeout"], 5)
        return result

    def test_all_preference_combinations(self):
        for mode in (0, 1, 2):
            for enabled in (True, False):
                result = self.probe(str(mode), json.dumps(enabled))
                self.assertEqual(result["mode"], mode)
                self.assertIs(result["filter_enabled"], enabled)
                self.assertIsNone(result["error"])
                self.assertEqual(result["version"], 1)
                self.assertIsInstance(result["checked_at"], int)

    def test_invalid_values(self):
        for value in ("true", "3", "0.0", '"0"', "null", "invalid"):
            result = self.probe(mode=value)
            self.assertIsNone(result["mode"])
            self.assertIs(result["filter_enabled"], True)
            self.assertIn("activeSilentMode", result["error"])
        for value in ("0", '"true"', "null", ""):
            self.assertIsNone(self.probe(enabled=value)["filter_enabled"])

    def test_errors_are_bounded_and_sanitized(self):
        for error in (
            FileNotFoundError("private path"),
            subprocess.TimeoutExpired("private command", 5),
            subprocess.CalledProcessError(1, "private command", output="private output"),
        ):
            with patch.object(publish.subprocess, "run", side_effect=error):
                result = publish.probe("taglia")
            self.assertIsNone(result["mode"])
            self.assertIsNone(result["filter_enabled"])
            self.assertNotIn("private", json.dumps(result))

    def test_failure_diagnostics_do_not_leak_raw_output(self):
        cases = [
            (subprocess.TimeoutExpired("private command", 5), {"kind": "timeout", "seconds": 5}),
            (subprocess.CalledProcessError(14, "private command", output="private output"),
             {"kind": "exit", "code": 14}),
            (PermissionError(13, "private path"), {"kind": "os_error", "errno": 13}),
        ]
        for error, expected in cases:
            with self.subTest(expected=expected):
                with patch.object(publish.subprocess, "run", side_effect=error):
                    result = publish.probe("taglia")
                self.assertEqual(result["failures"], {
                    "activeSilentMode": expected, "networkFilterEnabled": expected,
                })
                self.assertNotIn("private", json.dumps(result))
        for invalid in ("not JSON", '"0"', "3"):
            self.assertEqual(self.probe(mode=invalid)["failures"], {
                "activeSilentMode": {"kind": "parse_failure"},
            })
        self.assertEqual(self.probe()["failures"], {})

    def test_cli_disabled_is_distinct_from_other_failures(self):
        error = subprocess.CalledProcessError(
            1, publish.CLI,
            stderr="Error: command line tool is not authorized to make changes.\n"
            "Please enable access in Little Snitch.app > Preferences > Security.",
        )
        with patch.object(publish.subprocess, "run", side_effect=error):
            result = publish.probe("taglia")
        self.assertEqual(result["error_kind"], "cli_disabled")
        with patch.object(publish.subprocess, "run", side_effect=FileNotFoundError()):
            result = publish.probe("taglia")
        self.assertEqual(result["error_kind"], "probe_failed")

    def test_atomic_file_permissions_and_replacement(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "status"
            for value in ({"mode": 0}, {"mode": 1}):
                publish.publish(directory, value, owner_uid=os.getuid())
                target = directory / "status.json"
                self.assertEqual(json.loads(target.read_text()), value)
                self.assertEqual(target.stat().st_mode & 0o777, 0o644)
                self.assertEqual(list(directory.iterdir()), [target])

    def test_rejects_untrusted_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "status"
            directory.mkdir()
            with self.assertRaises(PermissionError):
                publish.publish(directory, {}, owner_uid=os.getuid() + 1)
            directory.chmod(0o777)
            with self.assertRaises(PermissionError):
                publish.publish(directory, {}, owner_uid=os.getuid())
            directory.chmod(0o755)
            link = Path(temporary) / "link"
            link.symlink_to(directory)
            with self.assertRaises(PermissionError):
                publish.publish(link, {}, owner_uid=os.getuid())


if __name__ == "__main__":
    unittest.main()
