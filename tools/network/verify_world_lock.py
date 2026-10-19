"""Real process coverage for the kernel-owned dedicated-world writer lock."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

helper = Path(__file__).with_name('durable_replace.py').resolve()
checks = 0
children = []

def start(target):
    process = subprocess.Popen([sys.executable, str(helper), '--worker', str(target), str(os.getpid())], stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    children.append(process)
    return process, json.loads(process.stdout.readline())


def verify(condition, label):
    global checks
    checks += 1
    if not condition:
        raise AssertionError(label)


try:
    with tempfile.TemporaryDirectory(prefix='world-rise-writer-lock-') as folder:
        target = Path(folder) / 'world.json'
        contenders = [start(target) for _ in range(4)]
        verify(sum(result.get('ready', False) for _, result in contenders) == 1, 'one winner for simultaneous fresh-world processes')
        verify(not target.exists() and not Path(str(target) + '.pending').exists(), 'lock acquisition cannot create a proposal or world')
        winner = next(process for process, result in contenders if result.get('ready'))
        winner.kill(); winner.wait(timeout=5)
        replacement, result = start(target)
        verify(result.get('ready'), 'writer crash releases OS lock')
        replacement.kill(); replacement.wait(timeout=5)
        owner_code = "import subprocess,sys,os,time,json; p=subprocess.Popen([sys.executable,sys.argv[1],'--worker',sys.argv[2],str(os.getpid())],stdout=subprocess.PIPE,text=True); print(p.stdout.readline().strip(),flush=True); time.sleep(60)"
        owner = subprocess.Popen([sys.executable, '-c', owner_code, str(helper), str(target)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        children.append(owner)
        verify(json.loads(owner.stdout.readline()).get('ready'), 'separate owner process acquires lock')
        owner.kill(); owner.wait(timeout=5)
        recovered = False
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            candidate, result = start(target)
            if result.get('ready'):
                recovered = True
                candidate.kill(); candidate.wait(timeout=5)
                break
            candidate.wait(timeout=5)
            time.sleep(.02)
        verify(recovered, 'parent crash releases orphan worker lock without stale PID cleanup')
    print(json.dumps({'checks': checks, 'failures': []}))
finally:
    for child in children:
        if child.poll() is None:
            child.kill()
        child.wait(timeout=5)
        for stream in (child.stdin, child.stdout, child.stderr):
            if stream:
                stream.close()
