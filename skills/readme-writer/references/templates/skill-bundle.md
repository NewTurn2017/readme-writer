# Template: skill-bundle

Claude Code / Codex CLI 스킬 묶음 레포용. HandOff 톤 기준. 새 머신에서 AI 에이전트가 README만 읽고 설치/사용 완료할 수 있는 자기완결성이 핵심.

## 권장 섹션 순서

1. **Header** — `# {Name}` + 한 줄 가치 제안 (`> {What it does in one sentence}`)
2. **Pitch (1 단락)** — 어떤 문제를 푸는지, 왜 다른지 (3-5줄)
3. **TL;DR — 한 줄 설치**
   - macOS / Linux: `curl -fsSL https://raw.githubusercontent.com/{owner}/{repo}/main/bootstrap.sh | bash`
   - 옵션 포함: `… | bash -s -- --hook` 같이 추가 인자 패턴
   - Windows (PowerShell): `iwr -useb https://raw.githubusercontent.com/{owner}/{repo}/main/bootstrap.ps1 | iex`
   - 검증 명령 1줄 (`ls -l ~/.claude/skills/...` 같은)
4. **AI 에이전트용 설치 가이드**
   - 사전 조건 표 (OS / 필요 도구)
   - 부트스트랩 환경 변수 표 (`HANDOFF_HOME` 같은 패턴)
   - 수동 설치 절차 (clone → install.sh)
   - `install.sh`가 하는 일 (번호 매긴 4-5단계)
   - 옵션 (`--claude` / `--codex` / `--hook` / `--uninstall`)
   - 백업 폴더 정리
   - 업데이트 / 제거
5. **두 스킬 개요** (스킬마다 한 블록)
   - 트리거 한국어/영어
   - 수집/저장 정보
   - 자동 마스킹 정책 (있다면)
6. **레포 구조** (`tree` 출력 인용)
7. **문서 스키마 / 데이터 형식** (frontmatter, JSON 등이 있으면)
8. **SessionStart 훅 / 통합 포인트 상세** (선택)
9. **환경 변수** 표
10. **개발 워크플로우** (single source of truth면 "수정 → 즉시 반영" 강조)
11. **수동 스모크 테스트** (script별 1-2줄 명령)
12. **라이선스**
13. **자동 생성 메타** (Step 4의 placeholder 모음)

## 톤 가이드

- 한국어 위주, 영어는 트리거 문구 / 코드 펜스 안에서 자연스럽게 혼용
- `idempotent` 강조 — 재실행해도 안전하다는 것을 표 또는 한 줄로 명시
- "AI 에이전트가 이 README만 보고…" 슬로건을 자연스럽게 포함
- 명령어는 모두 코드 블록으로, 출력 예시는 인용 블록 또는 `# OK` 주석으로
- 표를 적극 활용 (옵션, 환경변수, 분류)

## 인용해야 할 Step 1 결과

| 섹션 | 사용할 데이터 |
|------|---------------|
| Header pitch | `manifests[*].content`의 description, 또는 기존 README의 첫 단락 |
| TL;DR 한 줄 설치 | `bootstrap[*].file` 의 존재 여부 (`bootstrap.sh`/`bootstrap.ps1`) |
| 사전 조건 표 | `bootstrap[*].preview` 에서 `require`/`Need-Cmd` 호출 추출 |
| 환경 변수 표 | `env_signals.shell_grep` (shell `${VAR:-default}`) + `env_signals.code_grep` + `env_signals.env_example` 합집합 |
| install.sh 동작 | `bootstrap[*].preview` 직접 인용 |
| 트리거 문구 | `skill_triggers[*].description` 직접 인용 |
| 데이터/문서 스키마 섹션 | `skill_triggers[*].schemas[*].body` (스킬 SKILL.md 본문에서 추출) 직접 인용 |
| 보존할 사용자 섹션 | `existing_readme.section_headers` 중 분류 매트릭스에 없는 것 — 미리보기에서 확인 |
| 레포 구조 | `tree` 그대로 (200줄 이내) |
| 라이선스 | `license.spdx` |
| GitHub URL | `git.remote` (없으면 `[GitHub URL - 미지정]`) |

## DO NOT

- "Easy to install! Just one command!" 같은 마케팅 문구 X — 명령 자체가 한 줄이면 그게 증명이다
- 존재하지 않는 옵션을 추측해서 표에 넣지 말 것 (예: `--debug` 라는 플래그가 install.sh에 없으면 적지 말 것)
- 라이선스 추측 X — `license.spdx`가 unknown이면 placeholder로
- 한 줄 설치를 강제하지 말 것 — `bootstrap.sh`가 없으면 TL;DR 섹션 자체를 생략
