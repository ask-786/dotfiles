#!/usr/bin/env python3
"""BlueZ pairing agent for Quickshell (services/Bt.qml runs it).

Quickshell.Bluetooth can call Pair() but registers no agent, so devices that
need a passkey or a confirmation (keyboards, phones) failed to pair. This
registers one with KeyboardDisplay capability and hands every question to
Quickshell as JSON lines on stdout:

    {"id": 1, "kind": "display", "device": "/org/bluez/...", "name": "...",
     "address": "...", "code": "123456", "entered": 0}

kind is one of display (type `code` on the device), confirm (does `code`
match?), authorize (pair with no code?), service (allow `uuid`?), pin or
passkey (the user types one in). {"id": n, "kind": "clear"} withdraws a
question. Answers come back on stdin as {"id": n, "accept": bool, "value": s}.
Exits when stdin closes, i.e. when Quickshell stops it.
"""

import json
import random
import sys

try:
    from gi.repository import Gio, GLib
except ImportError:
    print("bt-agent: python-gobject is missing", file=sys.stderr)
    sys.exit(3)

AGENT_PATH = "/org/quickshell/btagent"

INTROSPECTION = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode">
      <arg type="o" direction="in"/><arg type="s" direction="out"/>
    </method>
    <method name="DisplayPinCode">
      <arg type="o" direction="in"/><arg type="s" direction="in"/>
    </method>
    <method name="RequestPasskey">
      <arg type="o" direction="in"/><arg type="u" direction="out"/>
    </method>
    <method name="DisplayPasskey">
      <arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/>
    </method>
    <method name="RequestConfirmation">
      <arg type="o" direction="in"/><arg type="u" direction="in"/>
    </method>
    <method name="RequestAuthorization">
      <arg type="o" direction="in"/>
    </method>
    <method name="AuthorizeService">
      <arg type="o" direction="in"/><arg type="s" direction="in"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>
"""

bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
loop = GLib.MainLoop()
pending = {}  # id -> (invocation, method name)
shown = {}  # id -> device path, for display questions (they get no reply)
watches = {}  # device path -> PropertiesChanged subscription
next_id = 0


def emit(**msg):
    print(json.dumps(msg), flush=True)


def device_props(path):
    try:
        res = bus.call_sync("org.bluez", path, "org.freedesktop.DBus.Properties", "GetAll",
                            GLib.Variant("(s)", ("org.bluez.Device1",)), None,
                            Gio.DBusCallFlags.NONE, 2000, None)
        return res.unpack()[0]
    except GLib.Error:
        return {}


def ask(path, kind, invocation=None, method=None, qid=None, **extra):
    global next_id
    if qid is None:
        next_id += 1
        qid = next_id
    props = device_props(path)
    if invocation:
        pending[qid] = (invocation, method)
    else:
        shown[qid] = path
        watch(path)
    emit(id=qid, kind=kind, device=path, name=props.get("Alias", ""),
         address=props.get("Address", ""), **extra)


def clear(qid):
    pending.pop(qid, None)
    shown.pop(qid, None)
    emit(id=qid, kind="clear")


# A display question gets no reply from BlueZ, so drop it once the device
# is paired. Failures end in Cancel(), or Quickshell drops it when its own
# Pair() call returns.
def watch(path):
    if path in watches:
        return

    def changed(_conn, _sender, _path, _iface, _signal, params):
        iface, props, _ = params.unpack()
        if iface == "org.bluez.Device1" and props.get("Paired"):
            for qid, p in list(shown.items()):
                if p == path:
                    clear(qid)
            bus.signal_unsubscribe(watches.pop(path))

    watches[path] = bus.signal_subscribe("org.bluez", "org.freedesktop.DBus.Properties",
                                         "PropertiesChanged", path, None,
                                         Gio.DBusSignalFlags.NONE, changed)


def is_keyboard(path):
    cls = device_props(path).get("Class", 0)
    return (cls >> 8) & 0x1F == 0x05 and cls & 0x40


def on_call(_conn, _sender, _path, _iface, method, params, invocation):
    args = params.unpack()
    if method == "RequestPinCode":
        # Legacy keyboards want the PIN typed on them, so pick one and show
        # it; anything else (old headsets want 0000) is asked for.
        if is_keyboard(args[0]):
            pin = f"{random.randint(0, 999999):06d}"
            ask(args[0], "display", code=pin, entered=0)
            invocation.return_value(GLib.Variant("(s)", (pin,)))
        else:
            ask(args[0], "pin", invocation, method)
    elif method == "RequestPasskey":
        ask(args[0], "passkey", invocation, method)
    elif method == "DisplayPinCode":
        ask(args[0], "display", code=args[1], entered=0)
        invocation.return_value(None)
    elif method == "DisplayPasskey":
        # Called again for each digit typed; update the same question.
        qid = next((q for q, p in shown.items() if p == args[0]), None)
        ask(args[0], "display", qid=qid, code=f"{args[1]:06d}", entered=args[2])
        invocation.return_value(None)
    elif method == "RequestConfirmation":
        ask(args[0], "confirm", invocation, method, code=f"{args[1]:06d}")
    elif method == "RequestAuthorization":
        ask(args[0], "authorize", invocation, method)
    elif method == "AuthorizeService":
        ask(args[0], "service", invocation, method, uuid=args[1])
    elif method == "Cancel":
        for qid in list(pending) + list(shown):
            clear(qid)
        invocation.return_value(None)
    elif method == "Release":
        invocation.return_value(None)
        loop.quit()


def on_answer(answer):
    entry = pending.pop(answer.get("id"), None)
    if not entry:
        return
    invocation, method = entry
    if not answer.get("accept"):
        invocation.return_dbus_error("org.bluez.Error.Rejected", "Rejected by user")
        return
    value = str(answer.get("value", "")).strip()
    if method == "RequestPinCode":
        invocation.return_value(GLib.Variant("(s)", (value,)))
    elif method == "RequestPasskey":
        try:
            invocation.return_value(GLib.Variant("(u)", (int(value),)))
        except ValueError:
            invocation.return_dbus_error("org.bluez.Error.Rejected", "Not a number")
    else:
        invocation.return_value(None)


def on_stdin(channel, condition):
    if condition & (GLib.IO_HUP | GLib.IO_ERR):
        loop.quit()
        return False
    line = channel.readline()
    if not line:
        loop.quit()
        return False
    try:
        on_answer(json.loads(line))
    except (ValueError, AttributeError):
        pass
    return True


def register(*_):
    try:
        for method, args in (("RegisterAgent", GLib.Variant("(os)", (AGENT_PATH, "KeyboardDisplay"))),
                             ("RequestDefaultAgent", GLib.Variant("(o)", (AGENT_PATH,)))):
            bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", method, args,
                          None, Gio.DBusCallFlags.NONE, 5000, None)
    except GLib.Error as e:
        print(f"bt-agent: {e.message}", file=sys.stderr)


node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
bus.register_object(AGENT_PATH, node.interfaces[0], on_call, None, None)
# (Re)register whenever bluetoothd appears, e.g. after a restart.
Gio.bus_watch_name_on_connection(bus, "org.bluez", Gio.BusNameWatcherFlags.NONE, register, None)

stdin = GLib.IOChannel.unix_new(sys.stdin.fileno())
GLib.io_add_watch(stdin, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)

loop.run()
