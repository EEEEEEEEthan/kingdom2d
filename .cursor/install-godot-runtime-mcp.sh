#!/usr/bin/env bash
set -euo pipefail

chmod +x addons/godot_runtime_mcp/agent_mcp.sh
python3 -m pip install -q -r addons/godot_runtime_mcp/requirements.txt 'mcp>=1,<2'

mkdir -p "${HOME}/.cursor"
python3 - <<'PY'
import json
from pathlib import Path

workspace = Path.cwd().resolve()
script = workspace / "addons" / "godot_runtime_mcp" / "agent_mcp.sh"
config = {
	"mcpServers": {
		"godot-game": {
			"command": "bash",
			"args": [str(script)],
		}
	}
}
destination = Path.home() / ".cursor" / "mcp.json"
destination.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
print(f"wrote {destination} -> {script}")
PY
