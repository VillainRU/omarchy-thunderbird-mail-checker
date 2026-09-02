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

state_dir="$XDG_STATE_HOME/thunderbird-mail-checker"
mkdir -p "$state_dir"
python - "$state_dir/status.json" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_bytes(b'{"padding":"' + b'x' * (2 * 1024 * 1024) + b'"}')
PY
chmod 0600 "$state_dir/status.json"
"$helper" status > "$task_tmp/oversized-status.json"
python - "$task_tmp/oversized-status.json" <<'PY'
import json, sys
status = json.load(open(sys.argv[1]))
assert status["connected"] is False
assert status["setupRequired"] is True
assert "padding" not in status
PY

export SYMLINK_VICTIM="$task_tmp/protected.json"
printf '%s\n' '{"protected":true}' > "$SYMLINK_VICTIM"
chmod 0600 "$SYMLINK_VICTIM"
rm "$state_dir/status.json"
ln -s "$SYMLINK_VICTIM" "$state_dir/status.json"
ln -s "$SYMLINK_VICTIM" "$state_dir/status.json.tmp"
"$helper" status > "$task_tmp/symlink-status.json"
python - "$task_tmp/symlink-status.json" <<'PY'
import json, sys
status = json.load(open(sys.argv[1]))
assert status["connected"] is False
assert status["setupRequired"] is True
assert "protected" not in status
PY

echo "status file safety: ok"

if "$helper" action open 123 > "$task_tmp/unavailable-action.json"; then
  echo "an unavailable action must fail instead of being queued" >&2
  exit 1
fi
python - "$task_tmp/unavailable-action.json" "$XDG_STATE_HOME" <<'PY'
import json, pathlib, sys
result = json.load(open(sys.argv[1]))
assert result["ok"] is False
assert "unavailable" in result["error"]
assert not (pathlib.Path(sys.argv[2]) / "thunderbird-mail-checker" / "queued-actions.json").exists()
PY

echo "unavailable action: not queued"

mock_bin="$task_tmp/mock-bin"
mkdir -p "$mock_bin"
export FOCUS_LOG="$task_tmp/hyprctl-focus.log"
cat > "$mock_bin/hyprctl" <<'SH'
#!/bin/bash
set -euo pipefail
if [[ ${1:-} == "-j" && ${2:-} == "clients" ]]; then
  printf '%s\n' '[{"address":"0xf00","class":"org.mozilla.Thunderbird","initialClass":"org.mozilla.Thunderbird","focusHistoryID":0}]'
elif [[ ${1:-} == "dispatch" ]]; then
  printf '%s\n' "$*" >> "$FOCUS_LOG"
  printf '%s\n' ok
else
  exit 1
fi
SH
chmod 0700 "$mock_bin/hyprctl"
export PATH="$mock_bin:$PATH"

python - "$helper" <<'PY'
import json
import os
import socket
import stat
import struct
import subprocess
import sys
import time

helper = sys.argv[1]
host = subprocess.Popen([helper, "native-host"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
subscriber = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)

def send(value):
    raw = json.dumps(value).encode()
    host.stdin.write(struct.pack("<I", len(raw)) + raw)
    host.stdin.flush()

def focus_commands():
    try:
        with open(os.environ["FOCUS_LOG"], encoding="utf-8") as source:
            return source.read().splitlines()
    except FileNotFoundError:
        return []

try:
    socket_path = os.path.join(os.environ["XDG_RUNTIME_DIR"], "thunderbird-mail-checker.sock")
    for _ in range(30):
        try:
            subscriber.connect(socket_path)
            break
        except (FileNotFoundError, ConnectionRefusedError):
            time.sleep(0.05)
    subscriber.sendall(b'{"type":"subscribe"}\n')
    subscriber_file = subscriber.makefile("r", encoding="utf-8")
    assert json.loads(subscriber_file.readline())["type"] == "status"
    send({"type": "ready"})
    header = host.stdout.read(4)
    size = struct.unpack("<I", header)[0]
    assert json.loads(host.stdout.read(size).decode())["type"] == "ready"
    send({"type": "snapshot", "status": {"connected": True, "unreadTotal": 7, "accounts": []}})
    pushed = json.loads(subscriber_file.readline())
    assert pushed["type"] == "status"
    assert pushed["status"]["unreadTotal"] == 7
    state_dir = os.path.join(os.environ["XDG_STATE_HOME"], "thunderbird-mail-checker")
    status_path = os.path.join(state_dir, "status.json")
    assert not os.path.islink(status_path)
    assert os.path.isfile(status_path)
    assert stat.S_IMODE(os.stat(status_path).st_mode) == 0o600
    assert open(os.environ["SYMLINK_VICTIM"], encoding="utf-8").read() == '{"protected":true}\n'
    assert os.path.islink(os.path.join(state_dir, "status.json.tmp"))
    subscriber.sendall(b'{"type":"action","requestId":"socket-action","action":"open","messageId":321}\n')
    header = host.stdout.read(4)
    size = struct.unpack("<I", header)[0]
    socket_request = json.loads(host.stdout.read(size).decode())
    assert socket_request["requestId"] == "socket-action"
    assert socket_request["messageId"] == 321
    send({"type": "action-result", "requestId": "socket-action", "ok": True})
    socket_result = json.loads(subscriber_file.readline())
    assert socket_result["type"] == "action-result"
    assert socket_result["ok"] is True
    assert focus_commands() == ['dispatch hl.dsp.focus({ window = "address:0xf00" })']
    subscriber.sendall(b'{"type":"action","requestId":"failed-open","action":"open","messageId":999}\n')
    header = host.stdout.read(4)
    size = struct.unpack("<I", header)[0]
    failed_request = json.loads(host.stdout.read(size).decode())
    send({"type": "action-result", "requestId": failed_request["requestId"], "ok": False, "error": "test failure"})
    failed_result = json.loads(subscriber_file.readline())
    assert failed_result["ok"] is False
    assert focus_commands() == ['dispatch hl.dsp.focus({ window = "address:0xf00" })']
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
    assert focus_commands() == [
        'dispatch hl.dsp.focus({ window = "address:0xf00" })',
        'dispatch hl.dsp.focus({ window = "address:0xf00" })',
    ]
    restart = json.loads(subprocess.check_output([helper, "restart"], text=True))
    assert restart["ok"] is True
    host.wait(timeout=3)
finally:
    subscriber.close()
    if host.poll() is None:
        host.terminate()
        host.wait(timeout=3)
PY

echo "native host socket: ok"
