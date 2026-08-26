#!/usr/bin/env bash
set -euo pipefail

# 云端用户级技能以 AgentSkills 为全集，同步到 ~/.cursor/skills
DEST="${HOME}/.cursor/skills"
URL="https://github.com/EEEEEEEEthan/AgentSkills.git"

mkdir -p "${HOME}/.cursor"
rm -rf "${DEST}"
git clone --depth 1 "${URL}" "${DEST}"
rm -rf "${DEST}/.git"
