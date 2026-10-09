#!/usr/bin/env python3
"""Desktop notification for Claude Code hooks, titled with the session's name.

Usage (from a hook): notify.py <stop|attention|question>
Reads the hook's JSON payload on stdin. Clicking the notification focuses the
session's terminal window, and its tmux pane when running inside tmux.
"""
import json
import os
import subprocess
import sys

SOUNDS = "/usr/share/sounds/freedesktop/stereo/"
KINDS = {
    "stop": ("normal", "Task finished", "complete.oga"),
    "attention": ("critical", "Needs your attention", "message-new-instant.oga"),
    "question": ("critical", "Has a question for you", "message-new-instant.oga"),
}


def session_title(transcript_path):
    """Latest user-set title (/rename) wins over the auto-generated one."""
    custom = ai = None
    try:
        with open(transcript_path) as f:
            for line in f:
                if '"custom-title"' not in line and '"ai-title"' not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if entry.get("type") == "custom-title":
                    custom = entry.get("customTitle") or custom
                elif entry.get("type") == "ai-title":
                    ai = entry.get("aiTitle") or ai
    except (OSError, TypeError):
        pass
    return custom or ai


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True).stdout
    except OSError:
        return ""


def ancestors(pid):
    """pid and its parents, nearest first."""
    chain = []
    while pid > 1 and pid not in chain:
        chain.append(pid)
        try:
            with open(f"/proc/{pid}/stat") as f:
                pid = int(f.read().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
    return chain


def focus_tmux(pane):
    """Bring a tmux client to `pane`; returns that client's pid, or None."""
    session = run("tmux", "display", "-p", "-t", pane, "#{session_name}").strip()
    if not session:
        return None  # pane is gone
    clients = []
    for line in run("tmux", "list-clients", "-F",
                    "#{client_activity} #{client_pid} #{client_session} #{client_name}").splitlines():
        activity, pid, csession, name = line.split(" ", 3)
        clients.append((csession == session, int(activity), int(pid), name))
    if not clients:
        return None  # session isn't attached anywhere
    # Prefer a client already on the session, else the last-used one.
    _, _, pid, name = max(clients)
    run("tmux", "switch-client", "-c", name, "-t", session)
    run("tmux", "select-window", "-t", pane)
    run("tmux", "select-pane", "-t", pane)
    return pid


def focus_window(pids):
    try:
        clients = json.loads(run("hyprctl", "-j", "clients") or "[]")
    except ValueError:
        return
    by_pid = {c["pid"]: c["address"] for c in clients}
    for pid in pids:
        if pid in by_pid:
            run("hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{by_pid[pid]}" }})')
            return


def notify_and_wait(urgency, title, body, chain):
    """Fork off a notify-send that waits for a click, so the hook returns now."""
    if os.fork():
        return
    os.setsid()
    devnull = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(devnull, fd)  # don't hold the hook's pipes open
    clicked = run("notify-send", "-u", urgency, "-a", "Claude Code",
                  "--action=default=Focus", "--wait", title, body).strip()
    if clicked == "default":
        pane = os.environ.get("TMUX_PANE")
        client = focus_tmux(pane) if pane and os.environ.get("TMUX") else None
        focus_window(ancestors(client) if client else chain)
    os._exit(0)


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "stop"
    urgency, body, sound = KINDS.get(kind, KINDS["stop"])
    try:
        data = json.load(sys.stdin)
    except ValueError:
        data = {}

    cwd = data.get("cwd") or os.getcwd()
    where = cwd.replace(os.path.expanduser("~"), "~", 1)
    title = session_title(data.get("transcript_path")) or os.path.basename(cwd) or "Claude Code"

    if kind == "attention" and data.get("message"):
        body = data["message"]
    elif kind == "question":
        try:
            body = data["tool_input"]["questions"][0]["question"]
        except (KeyError, IndexError, TypeError):
            pass

    notify_and_wait(urgency, title, f"{body} · {where}", ancestors(os.getppid()))
    subprocess.Popen(["paplay", "--property=media.role=event", SOUNDS + sound],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


if __name__ == "__main__":
    main()
