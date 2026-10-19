"""Fault-injection checks for private request acquisition, before any world commit."""
import importlib.util
import errno
import json
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('durable_replace', Path(__file__).with_name('durable_replace.py'))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def sharing_error(code):
    error = PermissionError('injected Windows sharing/lock violation')
    error.winerror = code
    return error


class RequestRetryChecks(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='world-rise-request-retry-')
        self.addCleanup(self.folder.cleanup)
        self.request = Path(self.folder.name) / 'private-request.json'
        self.payload = '{"id":7,"op":"commit"}'
        self.request.write_text(self.payload)

    def test_transient_sharing_read_delivers_request_once(self):
        real_read = Path.read_text
        attempts = []
        def injected(path, *args, **kwargs):
            attempts.append(path)
            if len(attempts) <= 2:
                raise sharing_error(32)
            return real_read(path, *args, **kwargs)
        with patch.object(Path, 'read_text', injected):
            self.assertEqual(helper.take_request(self.request), self.payload)
            self.assertIsNone(helper.take_request(self.request))
        self.assertFalse(self.request.exists())
        self.assertEqual(len(attempts), 4)

    def test_transient_lock_unlink_does_not_deliver_until_removed(self):
        real_unlink = Path.unlink
        attempts = []
        def injected(path, *args, **kwargs):
            attempts.append(path)
            if len(attempts) <= 2:
                raise sharing_error(33)
            return real_unlink(path, *args, **kwargs)
        with patch.object(Path, 'unlink', injected):
            self.assertEqual(helper.take_request(self.request), self.payload)
        self.assertEqual(len(attempts), 3)
        self.assertFalse(self.request.exists())

    def test_transient_windows_crt_read_denial_without_winerror_retries_once_delivery(self):
        real_read = Path.read_text
        attempts = []
        def injected(path, *args, **kwargs):
            attempts.append(path)
            if len(attempts) <= 2:
                raise PermissionError(errno.EACCES, 'injected CRT fopen sharing denial')
            return real_read(path, *args, **kwargs)
        with patch.object(helper.os, 'name', 'nt'), patch.object(Path, 'read_text', injected):
            self.assertEqual(helper.take_request(self.request), self.payload)
            self.assertIsNone(helper.take_request(self.request))
        self.assertEqual(len(attempts), 4)
        self.assertFalse(self.request.exists())

    def test_permanent_windows_crt_denial_is_bounded_reports_read_and_preserves_request(self):
        error = PermissionError(errno.EACCES, 'injected permanent CRT denial')
        with patch.object(helper.os, 'name', 'nt'), patch.object(Path, 'read_text', side_effect=error) as read:
            with self.assertRaises(PermissionError) as raised:
                helper.take_request(self.request, retry_seconds=0.01)
            self.assertGreater(read.call_count, 1)
        self.assertEqual(raised.exception.request_operation, 'read')
        self.assertEqual(self.request.read_text(), self.payload)

    def test_posix_permission_denial_is_immediate_and_preserves_request(self):
        error = PermissionError(errno.EACCES, 'injected POSIX access denial')
        with patch.object(helper.os, 'name', 'posix'), patch.object(Path, 'read_text', side_effect=error) as read:
            with self.assertRaises(PermissionError) as raised:
                helper.take_request(self.request)
            self.assertEqual(read.call_count, 1)
        self.assertEqual(raised.exception.request_operation, 'read')
        self.assertEqual(self.request.read_text(), self.payload)

    def test_other_io_error_remains_immediate_and_preserves_request(self):
        with patch.object(Path, 'read_text', side_effect=OSError('injected I/O failure')) as read:
            with self.assertRaisesRegex(OSError, 'I/O failure'):
                helper.take_request(self.request)
            self.assertEqual(read.call_count, 1)
        self.assertEqual(self.request.read_text(), self.payload)

    def test_fatal_request_error_reports_first_failure_without_committing(self):
        target = Path(self.folder.name) / 'world.json'
        target.write_text('accepted checkpoint sentinel')
        code = ("import runpy,sys; module=runpy.run_path(sys.argv[1]); "
                "exec(\"def injected_request(path):\\n raise OSError('injected fatal request read')\", module['worker'].__globals__); "
                "module['worker'].__globals__['take_request']=module['worker'].__globals__['injected_request']; "
                "raise SystemExit(module['worker'](sys.argv[2],int(sys.argv[3]),'a'*32))")
        result = subprocess.run([sys.executable, '-c', code, str(Path(helper.__file__).resolve()),
                                 str(target), str(os.getpid())], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        replies = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertTrue(replies[0]['ready'])
        self.assertFalse(replies[1]['ok'])
        self.assertIn('injected fatal request read', replies[1]['error'])
        self.assertEqual(target.read_text(), 'accepted checkpoint sentinel')

    def test_persistent_sharing_error_is_bounded_and_preserves_request(self):
        started = time.monotonic()
        with patch.object(Path, 'unlink', side_effect=sharing_error(32)) as remove:
            with self.assertRaises(PermissionError):
                helper.take_request(self.request, retry_seconds=0.01)
            self.assertGreater(remove.call_count, 1)
        self.assertLess(time.monotonic() - started, 0.5)
        self.assertEqual(self.request.read_text(), self.payload)
        self.assertEqual(remove.side_effect.request_operation, 'remove')


if __name__ == '__main__':
    unittest.main()
