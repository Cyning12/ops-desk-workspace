#!/usr/bin/env bash
set -euo pipefail

# graph-compile.sh（workspace）
# 递归编译 docs/_tech_graph/**/*.graph.yaml -> 同目录 *.md
# 并用 kit export 写出 shared/graph.json，再 check

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GRAPH_DIR="${ROOT_DIR}/docs/_tech_graph"
GRAPH_JSON="${GRAPH_DIR}/shared/graph.json"

cd "${ROOT_DIR}"

# D-PIN：默认 npx 钉 @3.0.2（可 KIT_CLI 覆盖）
KIT_CLI="${KIT_CLI:-spec-wave@3.0.2}"

GRAPH_INPUT_DIRS=()
while IFS= read -r dir; do
  [[ -n "${dir}" ]] || continue
  GRAPH_INPUT_DIRS+=("${dir}")
done < <(
  find "${GRAPH_DIR}" -type f -name '*.graph.yaml' -print |
    sed 's|/[^/]*\.graph\.yaml$||' |
    sort -u
)

if [[ ${#GRAPH_INPUT_DIRS[@]} -eq 0 ]]; then
  echo "error: no *.graph.yaml under ${GRAPH_DIR}" >&2
  exit 1
fi

mkdir -p "${GRAPH_DIR}/shared"

echo "[spec-wave] compiling graph yaml -> md (${#GRAPH_INPUT_DIRS[@]} dir(s); KIT_CLI=${KIT_CLI})"
for dir in "${GRAPH_INPUT_DIRS[@]}"; do
  rel="${dir#"${ROOT_DIR}"/}"
  echo "  compile --input ${rel}"
  npx --yes "${KIT_CLI}" graph yaml compile --input "${dir}" --all
done

echo "[spec-wave] export shared/graph.json"
npx --yes "${KIT_CLI}" graph yaml export --input "${GRAPH_DIR}" --out "${GRAPH_JSON}"

echo "[spec-wave] checking graph consistency"
for dir in "${GRAPH_INPUT_DIRS[@]}"; do
  rel="${dir#"${ROOT_DIR}"/}"
  echo "  check --input ${rel}"
  npx --yes "${KIT_CLI}" graph yaml check --input "${dir}" --all --graph-json "${GRAPH_JSON}"
done

echo "done"
