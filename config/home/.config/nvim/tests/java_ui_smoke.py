"""Real PTY keypress checks; only controls the Neovim process started here."""
import fcntl
import json
import os
import pty
import select
import signal
import struct
import subprocess
import termios
import threading
import time
from pathlib import Path

base = Path(os.environ["NVIM_JAVA_TEST_TMP"])
assert str(base).startswith("/tmp/nvim-java-")
assert os.environ.get("XDG_DATA_HOME", "").startswith("/tmp/nvim-java-")
base.mkdir(parents=True, exist_ok=False)
socket = str(base / "nvim.sock")
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
env = dict(os.environ, TERM="xterm-256color")
proc = subprocess.Popen(["nvim", "-n", "-i", "NONE", "--listen", socket], stdin=slave,
                        stdout=slave, stderr=slave, env=env, start_new_session=True)
os.close(slave)
captured = bytearray()

def drain():
    while proc.poll() is None:
        try:
            if select.select([master], [], [], 0.2)[0]:
                captured.extend(os.read(master, 65536))
        except OSError:
            return

thread = threading.Thread(target=drain, daemon=True)
thread.start()
checks = []

def rpc(code):
    expr = "json_encode(luaeval(" + json.dumps(code, ensure_ascii=False) + "))"
    result = subprocess.run(["nvim", "--server", socket, "--remote-expr", expr],
                            text=True, capture_output=True, timeout=5, env=env)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout)

def check(value, label):
    assert value, label
    checks.append(label)
    print("OK " + label, flush=True)

def wait(fn, label, timeout=15):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise RuntimeError("Neovim exited: " + str(proc.returncode))
        try:
            last = fn()
            if last:
                check(True, label)
                return last
        except (subprocess.TimeoutExpired, RuntimeError, json.JSONDecodeError):
            pass
        time.sleep(0.05)
    raise AssertionError(label + ": " + repr(last))

def state():
    value = rpc("(function() local p=require('snacks').picker.get()[1]; if not p then return {} end; "
                "return {source=p.opts.source,title=p.opts.title,count=#p.list.items,selected=vim.tbl_map("
                "function(i) return i.item.name or i.item.id end,p.list.selected)} end)()")
    return value if isinstance(value, dict) else {}

def send(keys):
    os.write(master, keys)

def java_picker(preselect=False):
    selected = "{is_selected=function(item) return item.name=='one' end}" if preselect else "{}"
    rpc("(function() vim.cmd.stopinsert(); _G.java_ui_done=false; _G.java_ui_result=nil; "
        "coroutine.wrap(function() _G.java_ui_result=require('jdtls.ui').pick_many("
        "{{name='one'},{name='two'}},'Java fields',function(item)return item.name end," + selected + "); "
        "_G.java_ui_done=true end)(); return true end)()")
    wait(lambda: state().get("source") == "jdtls-pick-many" and state().get("count") == 2,
         "Java field picker rendered")

try:
    wait(lambda: Path(socket).exists() and rpc("vim.v.vim_did_enter == 1"), "Neovim real UI entered")
    rpc("(function() _G.ui_errors={}; local original=vim.notify; vim.notify=function(msg,level,opts) "
        "if level==vim.log.levels.ERROR then table.insert(_G.ui_errors,tostring(msg)) end; return original(msg,level,opts) end; return true end)()")
    send(b" sp")
    wait(lambda: state().get("title", "").startswith("1."), "global sp opens wizard from dashboard", 25)
    check(rpc("package.loaded['jdtls'] == nil and #vim.lsp.get_clients()==0"), "wizard does not load Java services")
    for step in range(2, 7):
        send(b"\r")
        wait(lambda: state().get("title", "").startswith(str(step) + "."), "Enter advances wizard step " + str(step))
    check(state()["count"] > 20, "real dependency list populated")
    send(b"\t")
    wait(lambda: len(state().get("selected", [])) == 1, "Tab selects a dependency")
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    proc.send_signal(signal.SIGWINCH)
    wait(lambda: rpc("vim.o.columns == 80 and vim.o.lines == 24"), "wizard survives terminal resize")
    check(rpc("(function() for _,w in ipairs(vim.api.nvim_list_wins()) do local c=vim.api.nvim_win_get_config(w); "
              "if c.relative~='' then local p=vim.api.nvim_win_get_position(w); if p[1]<0 or p[2]<0 "
              "or vim.api.nvim_win_get_width(w)>vim.o.columns then return false end end end return true end)()"),
          "picker windows fit narrow terminal")
    send(b"\x1b")
    wait(lambda: rpc("not require('languages.java.spring.wizard')._running and #require('snacks').picker.get()==0"), "Esc cancels wizard and releases guard")
    rpc("(function() require('lazy').load({plugins={'nvim-jdtls'}}); return true end)()")
    java_picker(True)
    wait(lambda: state().get("selected") == ["one"], "constructor field preselection visible")
    send(b"\t")
    wait(lambda: not state().get("selected"), "Tab removes a preselected field")
    send(b"\t")
    wait(lambda: state().get("selected") == ["two"], "Tab selects next field")
    send(b"\r")
    wait(lambda: rpc("_G.java_ui_done == true"), "Enter completes Java coroutine")
    check(rpc("_G.java_ui_result") == [{"name": "two"}], "Java picker returns only selected field")
    java_picker()
    send(b"\x1b")
    wait(lambda: rpc("_G.java_ui_done == true"), "Esc completes Java cancellation")
    check(rpc("#_G.java_ui_result") == 0, "Java cancellation returns empty table")
    java_picker()
    rpc("(function() local p=require('snacks').picker.get()[1]; vim.api.nvim_set_current_win(p.list.win.win); vim.cmd.stopinsert(); return true end)()")
    send(b" ")
    wait(lambda: len(state().get("selected", [])) == 1, "Space toggles field in list window")
    send(b"\r")
    wait(lambda: rpc("_G.java_ui_done == true"), "list Enter confirms selection")
    check(not rpc("_G.ui_errors"), "no Lua/UI errors during actual keypresses")
    print("PASS " + str(len(checks)) + " real PTY UI checks", flush=True)
finally:
    if proc.poll() is None:
        try:
            rpc("(function() vim.cmd('qa!'); return true end)()")
        except Exception:
            pass
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
    os.close(master)
    (base / "terminal-output.bin").write_bytes(captured)
    (base / "checks.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2))
