#!/usr/bin/env bash
# scan_repo.sh — Step 1 of readme-writer.
# Collects repo metadata as JSON for the prompt steps to ground on.
# Usage: scan_repo.sh [target_path]
set -uo pipefail

target="${1:-.}"
cd "$target" 2>/dev/null || { echo '{"error":"target path not found"}'; exit 1; }
abs_cwd=$(pwd)

# Prefer fd, fall back to find.
if command -v fd >/dev/null 2>&1; then
  fd_cmd() { fd "$@"; }
else
  fd_cmd() {
    # Minimal shim: fd_cmd -t f --max-depth N glob → find with -name
    local depth=4 type=f globs=()
    while [ $# -gt 0 ]; do
      case "$1" in
        -t) type="$2"; shift 2 ;;
        --max-depth) depth="$2"; shift 2 ;;
        -g) globs+=("$2"); shift 2 ;;
        -e) globs+=("*.$2"); shift 2 ;;
        *) globs+=("$1"); shift ;;
      esac
    done
    if [ ${#globs[@]} -eq 0 ]; then
      find . -maxdepth "$depth" -type "$type" 2>/dev/null
    else
      for g in "${globs[@]}"; do
        find . -maxdepth "$depth" -type "$type" -name "$g" 2>/dev/null
      done
    fi
  }
fi

esc() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
esc_str() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

# Git metadata
git_top="" branch="" remote="" head=""
if top=$(git rev-parse --show-toplevel 2>/dev/null); then
  git_top="$top"
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  remote=$(git config --get remote.origin.url 2>/dev/null || echo "")
  head=$(git rev-parse --short HEAD 2>/dev/null || echo "")
fi

# File tree (max-depth 4, max 200 lines)
tree_full=$(fd_cmd -t f --max-depth 4 2>/dev/null | head -n 200)
tree_count=$(fd_cmd -t f --max-depth 4 2>/dev/null | wc -l | tr -d ' ')
tree_truncated=false
if [ "$tree_count" -gt 200 ]; then tree_truncated=true; fi

# Helper: read file head N lines safely
read_head() {
  local file="$1" n="${2:-60}"
  [ -f "$file" ] || return 1
  head -n "$n" "$file" 2>/dev/null
}

# Helper: full file if small, else head 100
read_smart() {
  local file="$1"
  [ -f "$file" ] || return 1
  local size
  size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
  if [ "${size:-0}" -lt 51200 ]; then
    cat "$file" 2>/dev/null
  else
    head -n 100 "$file" 2>/dev/null
    echo "..."
    echo "(truncated; original size: ${size} bytes)"
  fi
}

# Manifests — bash 3.2 compatible (no associative arrays)
ecosystem_for() {
  case "$1" in
    package.json) echo npm ;;
    pyproject.toml|setup.py) echo python ;;
    Cargo.toml) echo rust ;;
    go.mod) echo go ;;
    Gemfile) echo ruby ;;
    composer.json) echo php ;;
    pom.xml|build.gradle|build.gradle.kts) echo java ;;
    Package.swift) echo swift ;;
    pubspec.yaml) echo dart ;;
    *) echo unknown ;;
  esac
}

manifests_json="["
first=true
for f in package.json pyproject.toml setup.py Cargo.toml go.mod Gemfile composer.json pom.xml build.gradle build.gradle.kts Package.swift pubspec.yaml; do
  if [ -f "$f" ]; then
    [ "$first" = false ] && manifests_json+=","
    first=false
    content=$(read_smart "$f")
    eco=$(ecosystem_for "$f")
    manifests_json+="{\"file\":$(esc_str "$f"),\"ecosystem\":$(esc_str "$eco"),\"content\":$(printf '%s' "$content" | esc)}"
  fi
done
manifests_json+="]"

# Bootstrap / install scripts
bootstrap_json="["
first=true
for f in install.sh bootstrap.sh bootstrap.ps1 Makefile makefile Dockerfile docker-compose.yml docker-compose.yaml; do
  if [ -f "$f" ]; then
    [ "$first" = false ] && bootstrap_json+=","
    first=false
    preview=$(read_head "$f" 60)
    bootstrap_json+="{\"file\":$(esc_str "$f"),\"preview\":$(printf '%s' "$preview" | esc)}"
  fi
done
bootstrap_json+="]"

# License — try LICENSE / LICENSE.md / LICENSE.txt / COPYING
license_file="" license_head="" license_spdx="unknown"
for f in LICENSE LICENSE.md LICENSE.txt COPYING COPYING.md; do
  if [ -f "$f" ]; then license_file="$f"; license_head=$(read_head "$f" 30); break; fi
done
if [ -n "$license_file" ]; then
  case "$license_head" in
    *"MIT License"*|*"Permission is hereby granted, free of charge, to any person obtaining a copy"*) license_spdx="MIT" ;;
    *"Apache License"*"Version 2.0"*) license_spdx="Apache-2.0" ;;
    *"GNU GENERAL PUBLIC LICENSE"*"Version 3"*) license_spdx="GPL-3.0" ;;
    *"GNU GENERAL PUBLIC LICENSE"*"Version 2"*) license_spdx="GPL-2.0" ;;
    *"Mozilla Public License Version 2.0"*) license_spdx="MPL-2.0" ;;
    *"BSD 3-Clause License"*|*"Redistribution and use in source and binary forms"*"3."*) license_spdx="BSD-3-Clause" ;;
    *"BSD 2-Clause"*) license_spdx="BSD-2-Clause" ;;
    *"The Unlicense"*|*"This is free and unencumbered software"*) license_spdx="Unlicense" ;;
    *"ISC License"*) license_spdx="ISC" ;;
  esac
fi

# Env signals: .env.example + grep for env access patterns
env_example_lines=""
for f in .env.example .env.sample env.example .env.template; do
  [ -f "$f" ] && { env_example_lines=$(read_head "$f" 200); break; }
done

env_grep=""
shell_env_grep=""
if command -v rg >/dev/null 2>&1; then
  env_grep=$(rg -INH --max-count 50 -e 'process\.env\.[A-Z_][A-Z0-9_]*' -e 'os\.environ\[["'\''][A-Z_][A-Z0-9_]*["'\'']\]' -e 'os\.getenv\(["'\''][A-Z_][A-Z0-9_]*["'\'']' -e 'getenv\(["'\''][A-Z_][A-Z0-9_]*["'\'']' . 2>/dev/null | head -n 100)
  # Shell ${VAR:-default} / ${VAR-default} / ${VAR:?msg} patterns
  shell_env_grep=$(rg -INH --max-count 50 -t sh -t bash -e '\$\{[A-Z][A-Z0-9_]+(:?[-?=][^}]*)?\}' . 2>/dev/null | head -n 100)
  if [ -z "$shell_env_grep" ]; then
    # Fallback: include .ps1 and Makefile by globbing
    shell_env_grep=$(rg -INH --max-count 50 --type-add 'shellish:*.{sh,bash,zsh,ps1,Makefile,makefile}' -t shellish -e '\$\{[A-Z][A-Z0-9_]+(:?[-?=][^}]*)?\}' -e '\$env:[A-Z][A-Z0-9_]+' . 2>/dev/null | head -n 100)
  fi
else
  env_grep=$(grep -rIEn --max-count=50 'process\.env\.[A-Z_][A-Z0-9_]*|os\.environ\[["'\''][A-Z_][A-Z0-9_]*["'\'']\]|getenv\(["'\''][A-Z_][A-Z0-9_]*["'\'']' . 2>/dev/null | head -n 100)
  shell_env_grep=$(grep -rIEn --max-count=50 --include='*.sh' --include='*.bash' --include='*.ps1' --include='Makefile' '\$\{[A-Z][A-Z0-9_]+(:?[-?=][^}]*)?\}|\$env:[A-Z][A-Z0-9_]+' . 2>/dev/null | head -n 100)
fi

# Skill triggers + schema sections from SKILL.md
skill_triggers="["
first=true
while IFS= read -r f; do
  [ -z "$f" ] && continue
  desc=$(awk '/^---/{n++; next} n==1 && /^description:/ {sub(/^description:[[:space:]]*/,""); print; exit} n>=2 {exit}' "$f" 2>/dev/null)
  # Extract sections whose header mentions 스키마/schema/형식/format/스펙/spec
  schema=$(python3 - "$f" 2>/dev/null <<'PYEOF'
import sys, re
path = sys.argv[1]
try:
    text = open(path, encoding="utf-8", errors="replace").read()
except Exception:
    sys.exit(0)
# Strip frontmatter
if text.startswith("---"):
    end = text.find("\n---", 3)
    if end != -1:
        text = text[end+4:]
# Find ## or ### sections whose header contains schema-ish words
pattern = re.compile(
    r"^(#{2,3})[ \t]+([^\n]*?(스키마|schema|형식|format|스펙|spec|문서 구조|document schema)[^\n]*?)\s*$\n(.*?)(?=\n#{1,3}[ \t]|\Z)",
    re.M | re.S | re.I,
)
matches = pattern.findall(text)
out = []
for m in matches[:3]:
    out.append({"header": m[1].strip(), "body": m[3].strip()[:2000]})
import json
print(json.dumps(out, ensure_ascii=False))
PYEOF
)
  if [ -n "$desc" ]; then
    [ "$first" = false ] && skill_triggers+=","
    first=false
    schema_json="${schema:-[]}"
    skill_triggers+="{\"file\":$(esc_str "$f"),\"description\":$(esc_str "$desc"),\"schemas\":$schema_json}"
  fi
done < <(fd_cmd -t f --max-depth 4 SKILL.md 2>/dev/null)
skill_triggers+="]"

# Language signal — count Korean (Hangul) chars in existing READMEs + recent commits
hangul_count=0
total_count=0
for rf in README.md README.ko.md README.en.md docs/README.md; do
  if [ -f "$rf" ]; then
    body=$(cat "$rf" 2>/dev/null)
    h=$(printf '%s' "$body" | python3 -c 'import sys; s=sys.stdin.read(); ko=sum(1 for c in s if 0xAC00 <= ord(c) <= 0xD7A3); print(ko, len(s))' 2>/dev/null)
    set -- $h
    hangul_count=$((hangul_count + ${1:-0}))
    total_count=$((total_count + ${2:-0}))
  fi
done
if [ -n "$git_top" ]; then
  commits=$(git log -10 --pretty=format:'%s' 2>/dev/null)
  h=$(printf '%s' "$commits" | python3 -c 'import sys; s=sys.stdin.read(); ko=sum(1 for c in s if 0xAC00 <= ord(c) <= 0xD7A3); print(ko, len(s))' 2>/dev/null)
  set -- $h
  hangul_count=$((hangul_count + ${1:-0}))
  total_count=$((total_count + ${2:-0}))
fi
ko_ratio=0
if [ "$total_count" -gt 0 ]; then
  ko_ratio=$(python3 -c "print(round($hangul_count / $total_count, 3))" 2>/dev/null || echo 0)
fi

# Monorepo signals
monorepo_signals="["
first=true
for f in pnpm-workspace.yaml lerna.json nx.json turbo.json rush.json; do
  if [ -f "$f" ]; then
    [ "$first" = false ] && monorepo_signals+=","
    first=false
    monorepo_signals+="$(esc_str "$f")"
  fi
done
# packages/* or apps/* with multiple subdirs
for d in packages apps; do
  if [ -d "$d" ]; then
    n=$(find "$d" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [ "$n" -ge 2 ]; then
      [ "$first" = false ] && monorepo_signals+=","
      first=false
      monorepo_signals+="$(esc_str "$d/ ($n entries)")"
    fi
  fi
done
# package.json with workspaces field
if [ -f package.json ]; then
  has_ws=$(python3 -c 'import json,sys; d=json.load(open("package.json")); print(1 if "workspaces" in d else 0)' 2>/dev/null || echo 0)
  if [ "$has_ws" = "1" ]; then
    [ "$first" = false ] && monorepo_signals+=","
    first=false
    monorepo_signals+="$(esc_str "package.json:workspaces")"
  fi
fi
monorepo_signals+="]"

# Existing README — capture path, size, head, AND section headers (for merge/preserve hints)
existing_readme="null"
for rf in README.md README.markdown readme.md; do
  if [ -f "$rf" ]; then
    size=$(wc -c < "$rf" 2>/dev/null | tr -d ' ')
    head5=$(head -n 5 "$rf" 2>/dev/null)
    headers=$(grep -E '^#{1,3} ' "$rf" 2>/dev/null | head -n 40)
    existing_readme="{\"path\":$(esc_str "$rf"),\"bytes\":${size:-0},\"head5\":$(printf '%s' "$head5" | esc),\"section_headers\":$(printf '%s' "$headers" | esc)}"
    break
  fi
done

# Webapp signals
web_signals="["
first=true
for f in next.config.js next.config.ts next.config.mjs vite.config.js vite.config.ts nuxt.config.js nuxt.config.ts svelte.config.js astro.config.mjs remix.config.js; do
  if [ -f "$f" ]; then
    [ "$first" = false ] && web_signals+=","
    first=false
    web_signals+="$(esc_str "$f")"
  fi
done
web_signals+="]"

# Final JSON assembly
cat <<EOF
{
  "abs_cwd": $(esc_str "$abs_cwd"),
  "git": {
    "toplevel": $(esc_str "$git_top"),
    "branch": $(esc_str "$branch"),
    "remote": $(esc_str "$remote"),
    "head": $(esc_str "$head")
  },
  "tree": $(printf '%s' "$tree_full" | esc),
  "tree_count": ${tree_count:-0},
  "tree_truncated": $tree_truncated,
  "manifests": $manifests_json,
  "bootstrap": $bootstrap_json,
  "license": {
    "file": $(esc_str "$license_file"),
    "spdx": $(esc_str "$license_spdx"),
    "head": $(printf '%s' "$license_head" | esc)
  },
  "env_signals": {
    "env_example": $(printf '%s' "$env_example_lines" | esc),
    "code_grep": $(printf '%s' "$env_grep" | esc),
    "shell_grep": $(printf '%s' "$shell_env_grep" | esc)
  },
  "skill_triggers": $skill_triggers,
  "language_signal": {
    "korean_chars": $hangul_count,
    "total_chars": $total_count,
    "korean_ratio": $ko_ratio
  },
  "monorepo_signals": $monorepo_signals,
  "webapp_signals": $web_signals,
  "existing_readme": $existing_readme
}
EOF
