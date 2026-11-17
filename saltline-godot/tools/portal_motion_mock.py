"""Private-session portal fixture; uses the host's existing PyGObject, no app dependency."""
import argparse
import os
from pathlib import Path
import subprocess

from gi.repository import Gio, GLib

parser = argparse.ArgumentParser()
parser.add_argument("initial", choices=["0", "1", "missing"])
parser.add_argument("--boot", action="store_true")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
state = {"value": int(args.initial) if args.initial != "missing" else None, "reads": 0}
xml = """<node><interface name="org.freedesktop.portal.Settings">
<method name="Read"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="out"/></method>
<property name="version" type="u" access="read"/>
<signal name="SettingChanged"><arg type="s"/><arg type="s"/><arg type="v"/></signal>
</interface><interface name="org.saltline.MotionTest">
<method name="SetMotion"><arg type="u" direction="in"/></method><method name="WrongType"/><method name="OtherKey"/>
<method name="GetReadCount"><arg type="u" direction="out"/></method>
</interface></node>"""
node = Gio.DBusNodeInfo.new_for_xml(xml)
connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
path = "/org/freedesktop/portal/desktop"

def signal(key, value):
    connection.emit_signal(None, path, "org.freedesktop.portal.Settings", "SettingChanged",
                           GLib.Variant("(ssv)", ("org.freedesktop.appearance", key, value)))

def call(_connection, _sender, _path, interface, method, parameters, invocation):
    if interface == "org.freedesktop.portal.Settings":
        namespace, key = parameters.unpack()
        if namespace == "org.freedesktop.appearance" and key == "reduced-motion":
            state["reads"] += 1
            if state["value"] is None:
                invocation.return_dbus_error("org.freedesktop.portal.Error.NotFound", "Missing fixture key")
                return
            value = state["value"]
        else:
            value = 0
        # Legacy Read intentionally returns two variant layers.
        invocation.return_value(GLib.Variant("(v)", (GLib.Variant("v", GLib.Variant("u", value)),)))
    elif method == "SetMotion":
        state["value"] = parameters.unpack()[0]
        signal("reduced-motion", GLib.Variant("u", state["value"]))
        invocation.return_value(None)
    elif method == "WrongType":
        signal("reduced-motion", GLib.Variant("s", "invalid"))
        invocation.return_value(None)
    elif method == "OtherKey":
        signal("unrelated", GLib.Variant("u", 0))
        invocation.return_value(None)
    else:
        invocation.return_value(GLib.Variant("(u)", (state["reads"],)))

for interface in node.interfaces:
    connection.register_object(path, interface, call,
                               lambda *_: GLib.Variant("u", 2), None)
# The private fixture has no accessibility service; prevent host service auto-starts.
for name in ["org.freedesktop.portal.Desktop", "org.a11y.Bus"]:
    connection.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                         "RequestName", GLib.Variant("(su)", (name, 0)),
                         GLib.VariantType.new("(u)"), Gio.DBusCallFlags.NONE, -1, None)
environment = os.environ.copy()
tag = args.initial + ("-boot" if args.boot else "")
environment["XDG_DATA_HOME"] = "/tmp/saltline-portal-motion-" + tag
environment["SALTLINE_TEST_MOTION_INITIAL"] = "-1" if args.initial == "missing" else args.initial
environment["SALTLINE_TEST_MOTION_REPORT"] = str(root / ("evidence/portal-motion-" + tag + ".json"))
process = subprocess.Popen([str(root / "tools/run_native.sh"), "--accessibility", "disabled", "--log-file", "/tmp/saltline-portal-motion-" + tag + ".log",
                            "--script", "tools/verify_boot_runtime.gd" if args.boot else "tools/verify_portal_motion.gd", "--", "--game"], env=environment)
loop = GLib.MainLoop()
def poll():
    if process.poll() is not None:
        loop.quit()
        return False
    return True
def timeout():
    process.terminate()
    return False
GLib.timeout_add(50, poll)
GLib.timeout_add_seconds(60, timeout)
loop.run()
raise SystemExit(process.wait())
