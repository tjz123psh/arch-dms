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
profile = base / "profile"
(profile / "data/nvim").mkdir(parents=True)
for part in ("lazy", "mason", "site"):
    (profile / "data/nvim" / part).symlink_to(Path(os.environ["XDG_DATA_HOME"]) / "nvim" / part, target_is_directory=True)
env = dict(os.environ, TERM="xterm-256color", XDG_DATA_HOME=str(profile / "data"), XDG_STATE_HOME=str(profile / "state"), XDG_CACHE_HOME=str(profile / "cache"))
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
    detail = rpc("{mode=vim.fn.mode(),filetype=vim.bo.filetype,line=vim.api.nvim_get_current_line()}")
    raise AssertionError(label + ": " + repr(last) + "; state=" + repr(detail))

def run(code):
    return rpc("(function() " + code + "; return true end)()")

def send(keys):
    os.write(master, keys)

def resize(cols, rows):
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    proc.send_signal(signal.SIGWINCH)
    wait(lambda: rpc("vim.o.columns == " + str(cols) + " and vim.o.lines == " + str(rows)), "resize " + str(cols) + "x" + str(rows))

def picker():
    value = rpc("(function() local p=require('snacks').picker.get()[1]; return p and {title=p.opts.title,source=p.opts.source,count=#p.list.items} or {} end)()")
    return value if isinstance(value, dict) else {}

def close_picker():
    send(b"\x1b")
    wait(lambda: rpc("#require('snacks').picker.get()==0"), "Esc closes picker")

def fits():
    return rpc("(function() local p=require('snacks').picker.get()[1]; if not p then return false end; for _,view in ipairs({p.input.win,p.list.win,p.preview.win}) do local w=view.win; if w and vim.api.nvim_win_is_valid(w) then local pos=vim.api.nvim_win_get_position(w); if pos[1]<0 or pos[2]<0 or pos[1]+vim.api.nvim_win_get_height(w)>vim.o.lines or pos[2]+vim.api.nvim_win_get_width(w)>vim.o.columns then return false end end end; return true end)()")

try:
    wait(lambda: Path(socket).exists() and rpc("vim.v.vim_did_enter == 1"), "Neovim real UI entered")
    run("vim.g.core_autosave=false; _G.core_errors={}; local old=vim.notify; vim.notify=function(msg,level,opts) if level==vim.log.levels.ERROR then table.insert(_G.core_errors,tostring(msg)) end; return old(msg,level,opts) end")
    check(rpc("package.loaded['core.ui.reference']==nil"), "guide data stays unloaded until requested")
    send(b" hk")
    wait(lambda: rpc("vim.bo.filetype=='cheatsheet'"), "leader hk opens guide")
    send(b"j\x04q")
    wait(lambda: rpc("vim.bo.filetype~='cheatsheet'"), "guide scroll and close")
    for cols, rows in ((60,18),(80,24),(120,30),(160,50)):
        resize(cols, rows)
        run("_G.choice_count=0; vim.ui.select({'one','two','three'}, {prompt='Core choose'}, function(choice) _G.choice_count=_G.choice_count+1; _G.choice_value=choice end)")
        wait(lambda: picker().get('count') == 3, "three-item select rendered")
        check(fits(), "selector fits screen")
        send(b"\r")
        wait(lambda: rpc("_G.choice_count==1"), "Enter confirms once")
        check(rpc("_G.choice_value=='one'"), "selection value preserved")
        run("_G.choice_count=0; vim.ui.select({'one'}, {prompt='Core cancel'}, function(choice) _G.choice_count=_G.choice_count+1; _G.choice_value=choice end)")
        wait(lambda: picker().get('count') == 1, "one-item select rendered")
        close_picker()
        check(rpc("_G.choice_count==1 and _G.choice_value==nil"), "Esc cancels once")
    resize(120, 40)
    run("_G.input_done=false; vim.ui.input({prompt='Core input'}, function(value) _G.input_done=true; _G.input_value=value end)")
    wait(lambda: rpc("vim.bo.filetype=='snacks_input'"), "Snacks input rendered")
    send(b"\x1b")
    wait(lambda: rpc("vim.fn.mode():sub(1,1)=='n'"), "input Esc leaves Insert mode")
    send(b"\x1b")
    wait(lambda: rpc("_G.input_done and _G.input_value==nil"), "input normal-mode Esc cancels")
    run("_G.noice_done=false; vim.schedule(function() _G.noice_value=vim.fn.input('Core Noice: '); _G.noice_done=true end)")
    wait(lambda: rpc("vim.fn.mode()=='c'"), "Noice input entered")
    send(b"\x1b")
    wait(lambda: rpc("_G.noice_done and _G.noice_value==''"), "Noice input cancels")

    search = base / 'grep'
    search.mkdir()
    (search / 'sample.txt').write_text('needle one\nneedle two\nother\n')
    run("require('snacks').picker.grep({cwd=" + json.dumps(str(search)) + ", search='needle', live=false})")
    wait(lambda: picker().get('count',0)>=2, "real grep found fixture matches")
    for cols, rows in ((160,50),(80,24),(60,18),(120,30)):
        resize(cols, rows)
        wait(fits, "grep layout remains inside resized screen")
        check(rpc("(function() local p=require('snacks').picker.get()[1]; return p.list.win:dim().height>=2 end)()"), "grep list retains more than one row")
    close_picker()
    for skin in ('pink','soft','pink','soft'):
        run("vim.cmd.PickerSkin('" + skin + "')")
    run("vim.cmd.colorscheme('catppuccin-mocha')")
    wait(lambda: rpc("vim.api.nvim_get_hl(0,{name='SnacksPickerBorder'}).fg==0x7f849c"), "soft border returns after ColorScheme")

    target = 'ZetaTarget90210' + base.name.replace('-', '')
    a, b = base/'project AlphaSource', base/('project ' + target)
    for path in (a,b):
        path.mkdir()
        (path/'pom.xml').write_text('<project/>\n')
    run("require('core.projects.history').mirror(" + json.dumps(str(a)) + "); require('core.projects.history').mirror(" + json.dumps(str(b)) + "); vim.api.nvim_set_current_dir(" + json.dumps(str(a)) + "); vim.cmd.Projects()")
    wait(lambda: picker().get('source')=='project-history', "project picker rendered")
    send(target.encode())
    wait(lambda: picker().get('count')==1, "project filtering handles spaces")
    send(b"\r")
    wait(lambda: rpc("vim.fn.getcwd()==" + json.dumps(str(b))), "project confirmation changes cwd")
    run("require('neo-tree.command').execute({action='show',source='filesystem',dir=" + json.dumps(str(b)) + "}); require('core.projects').switch(" + json.dumps(str(a)) + ")")
    wait(lambda: rpc("(function() local found=false; require('neo-tree.sources.manager')._for_each_state('filesystem',function(s) if s.path==" + json.dumps(str(a)) + " then found=true end end); return found end)()"), "file tree follows project change")
    run("require('neo-tree.command').execute({action='close'})")
    for path in (base/'one.txt',base/'two.txt'):
        path.write_text('original\n')
    run("vim.cmd('only!'); vim.cmd.edit(" + json.dumps(str(base/'one.txt')) + "); vim.cmd.vsplit(" + json.dumps(str(base/'two.txt')) + "); vim.cmd.BufDelete()")
    check(rpc("#vim.api.nvim_list_wins()==2"), "BufDelete preserves split layout")
    run("vim.cmd('only!'); vim.cmd.enew({bang=true}); vim.bo.filetype='python'; vim.cmd.startinsert()")
    wait(lambda: rpc("vim.fn.mode():sub(1,1)=='i' and vim.bo.filetype=='python'"), "Python input ready")
    send('（你好，world）！'.encode())
    wait(lambda: rpc("vim.api.nvim_get_current_line()=='(你好,world)!'"), "real UTF-8 input converts punctuation")
    send(b"\x1b")
    wait(lambda: rpc("vim.fn.mode():sub(1,1)=='n'"), "Python input has left Insert mode")
    run("vim.cmd('enew!'); vim.bo.filetype='text'; vim.cmd.startinsert()")
    wait(lambda: rpc("vim.fn.mode():sub(1,1)=='i' and vim.bo.filetype=='text'"), "text input ready")
    send('你好，世界！'.encode())
    wait(lambda: rpc("vim.api.nvim_get_current_line()=='你好，世界！'"), "text input keeps full-width punctuation")
    send(b"\x1b")
    wait(lambda: rpc("vim.fn.mode():sub(1,1)=='n'"), "text input has left Insert mode")
    run("vim.cmd('enew!'); _G.core_test_jobs={}")
    for ident, key, direction in ((1,b' tt','float'),(2,b' th','horizontal'),(3,b' tv','vertical')):
        send(key)
        wait(lambda i=ident: rpc("(function() local t=require('toggleterm.terminal').get(" + str(i) + ",true); return t and t.job_id~=nil end)()"), "terminal " + str(ident) + " starts")
        run("local t=require('toggleterm.terminal').get(" + str(ident) + ",true); _G.core_test_jobs[#_G.core_test_jobs+1]=t.job_id")
        check(rpc("require('toggleterm.terminal').get(" + str(ident) + ",true).direction=='" + direction + "'"), "terminal direction " + direction)
        send(b'jk')
        wait(lambda: rpc("vim.fn.mode():sub(1,1)=='n'"), "jk exits terminal input")
    check(rpc("#_G.core_errors==0"), "no captured UI errors")
    print('PASS ' + str(len(checks)) + ' real UI checks', flush=True)
finally:
    try:
        run("for _,job in ipairs(_G.core_test_jobs or {}) do pcall(vim.fn.jobstop,job) end; vim.g.core_autosave=false; vim.cmd('qa!')")
    except (Exception,):
        pass
    try:
        proc.wait(timeout=8)
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill(); proc.wait()
    os.close(master)
    (base/'screen.ansi').write_bytes(captured)
