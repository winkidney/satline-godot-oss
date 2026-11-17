"""Check the existing launcher without opening a window or writing user state."""
import contextlib
import hashlib
import io
import json
import runpy
import tempfile
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "tools/run.py"
checks = []
with tempfile.TemporaryDirectory(prefix="saltline-launcher-") as directory:
    root = Path(directory)
    (root / "tools").mkdir()
    (root / "evidence").mkdir()
    script = root / "tools/run.py"
    script.write_bytes(source.read_bytes())
    cases = [([], {}, "run"), (["run"], {}, "run"), (["capture"], {}, "capture"), (["import"], {}, "import"), (["run"], {"GODOT": "/tmp/custom-godot"}, "run"), (["import"], {"GODOT": "/tmp/editor-godot"}, "import")]
    for args, environment, mode in cases:
        with patch("sys.argv", [str(script), *args]), patch.dict("os.environ", environment | {"DISPLAY": ":99"}, clear=True), patch("subprocess.Popen") as launch, contextlib.redirect_stdout(io.StringIO()):
            launch.return_value.stdout = ["Launcher fixture\n"]
            launch.return_value.wait.return_value = 0
            runpy.run_path(str(script), run_name="__main__")
            command = launch.call_args.args[0]
            if mode == "import" or "GODOT" in environment:
                assert command[:3] == ["rtk", "proxy", environment.get("GODOT", "godot")]
            else:
                assert command[:3] == ["rtk", "proxy", str(root / "tools/run_native.sh")]
            if mode == "import":
                assert command[-3:] == ["--headless", "--editor", "--import"]
            else:
                assert command[-2:] == ["--", "--capture" if mode == "capture" else "--game"]
            assert launch.call_args.kwargs["env"]["XDG_DATA_HOME"] == "/tmp/saltline-port-data"
            checks.append({"mode": mode, "override": "GODOT" in environment})
    for output, code in [("SHADER ERROR: fixture\n", 0), ("fixture\n", 2)]:
        with patch("sys.argv", [str(script), "run"]), patch.dict("os.environ", {}, clear=True), patch("subprocess.Popen") as launch, contextlib.redirect_stdout(io.StringIO()):
            launch.return_value.stdout = [output]
            launch.return_value.wait.return_value = code
            try:
                runpy.run_path(str(script), run_name="__main__")
            except SystemExit as error:
                assert error.code == 1
            else:
                raise AssertionError("Launcher swallowed engine failure")
            checks.append({"error_propagation": output.strip(), "exit": code})
report = {"checks": len(checks), "cases": checks, "failures": [], "launcher_sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "scope": "Actual run.py executed from an isolated temporary tree; subprocess boundary mocked to check default full-game command, capture/import, explicit engine overrides and engine error propagation. Actual desktop launch is a separate check."}
(ROOT / "evidence/run-launcher-verification.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
