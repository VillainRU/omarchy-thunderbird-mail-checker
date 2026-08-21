#!/bin/bash
set -euo pipefail

task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
export XDG_STATE_HOME="$task_tmp/state"
export XDG_RUNTIME_DIR="$task_tmp/runtime"
mkdir -p "$XDG_RUNTIME_DIR"

helper="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/thunderbird-mail-checker"
"$helper" status > "$task_tmp/status.json"
python - "$task_tmp/status.json" <<'PY'
import json, sys
status = json.load(open(sys.argv[1]))
assert status["connected"] is False
assert status["setupRequired"] is True
PY

echo "protocol fallback: ok"

python - "$helper" <<'PY'
import json
import os
import struct
import subprocess
import sys
import time

helper = sys.argv[1]
host = subprocess.Popen([helper, "native-host"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

def send(value):
    raw = json.dumps(value).encode()
    host.stdin.write(struct.pack("<I", len(raw)) + raw)
    host.stdin.flush()

try:
    send({"type": "ready"})
    send({"type": "snapshot", "status": {"connected": True, "unreadTotal": 7, "accounts": []}})
    time.sleep(0.3)
    status = json.loads(subprocess.check_output([helper, "status"], text=True))
    assert status["connected"] is True
    assert status["unreadTotal"] == 7
    action = subprocess.Popen([helper, "action", "open", "123"], stdout=subprocess.PIPE, text=True)
    header = host.stdout.read(4)
    size = struct.unpack("<I", header)[0]
    request = json.loads(host.stdout.read(size).decode())
    assert request["type"] == "action"
    assert request["action"] == "open"
    assert request["messageId"] == 123
    send({"type": "action-result", "requestId": request["requestId"], "ok": True})
    assert json.loads(action.communicate(timeout=3)[0])["ok"] is True
finally:
    host.terminate()
    host.wait(timeout=3)
PY

echo "native host socket: ok"
