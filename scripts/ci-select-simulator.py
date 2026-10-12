"""CI only: choose an installed iPhone with iOS >= the deployment target."""
import json
import os
import subprocess

inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "--json"]))
candidates = []
for runtime in inventory["runtimes"]:
    if not runtime.get("isAvailable") or runtime.get("platform") not in (None, "iOS"):
        continue
    if "iOS" not in runtime["identifier"]:
        continue
    version = tuple(int(part) for part in runtime["version"].split("."))
    if version < (26, 5):
        continue
    for device in inventory["devices"].get(runtime["identifier"], []):
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            candidates.append((version, device["name"], device["udid"]))
if not candidates:
    raise SystemExit("No available iPhone simulator with iOS >= 26.5; check the runner image")
version, name, identifier = max(candidates)
print(f"Using {name}, iOS {version}: {identifier}")
with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as output:
    output.write(f"CI_SIMULATOR_ID={identifier}\n")
