---
name: readme-writer
description: This skill should be used when the user asks to "README 써줘", "README 만들어줘", "이 레포 README 자동 생성", "문서화해줘", "리드미 좀 만들어", "write README", "generate readme", "document this repo", "auto-generate readme", "create readme from scratch". Use this skill whenever the user wants a high-quality README produced by analyzing the actual repository code (not a generic template). Trigger even if the user only says "README" while clearly intending to create or rewrite the file. Do NOT trigger for partial edits like "add a badge to README" or for conceptual questions like "what is a README?".
---

# README Writer

> 레포의 실제 코드를 직접 읽어 자기완결적인 README.md를 생성한다. 새 머신에서 AI 에이전트가 이 README만 보고 설치·사용을 완료할 수 있는 것을 품질 기준으로 삼는다.

## When this skill applies

사용자가 "이 레포에 README 써줘" 같은 자연어로 호출했을 때 트리거된다. 인자로 레포 경로를 받을 수 있고, 없으면 현재 작업 디렉터리(cwd)를 사용한다. 기존 `README.md`가 있으면 `README.md.bak`으로 백업한 뒤 덮어쓰며, 사용자 확인 없이는 절대 저장하지 않는다.

이 스킬은 **템플릿 복붙이 아니다.** 매 호출마다 레포의 매니페스트·진입점·환경변수·설치 스크립트를 실제로 읽고, 거기서 grounding한 사실만 README에 적는다.

## Workflow

### Step 1: Scan the repo
**Type**: script

`scripts/scan_repo.sh`를 실행하여 JSON으로 메타데이터를 수집한다. 스크립트는 다음을 반환한다:

- `cwd`, `git_toplevel`, `branch`, `remote`, `head` — git 메타데이터 (없으면 null)
- `manifests` — 발견된 패키지 매니페스트와 핵심 필드 (`package.json` name/version/description/scripts/main/bin, `pyproject.toml` project 섹션, `Cargo.toml` package, `go.mod` module)
- `bootstrap` — `install.sh`/`bootstrap.sh`/`bootstrap.ps1`/`Makefile`/`Dockerfile`/`docker-compose.yml` 존재 여부 + 첫 60줄 미리보기
- `license` — `LICENSE*` 파일의 SPDX 추론 결과 (MIT/Apache-2.0/GPL-3.0 등)
- `env_signals` — `.env.example` 라인, 코드 내 `process.env.X` / `os.environ["X"]` / `getenv("X")` grep 결과, **shell `${VAR:-default}` / `$env:VAR` 패턴 grep** (shell 스크립트 기반 도구의 환경 변수 추출)
- `skill_triggers` — `**/SKILL.md` frontmatter `description` 필드 + 본문에서 "스키마/schema/형식/format/spec" 헤더 섹션 본문 추출 (스킬 묶음 레포의 데이터 형식 인용용)
- `language_signal` — 기존 `README*.md` 본문 + 코드 주석 첫 N줄 + 최근 커밋 메시지 10개의 한국어 문자 비율
- `monorepo_signal` — `packages/`/`apps/` 디렉터리, `pnpm-workspace.yaml`, `lerna.json`, `nx.json`, root `package.json`의 `workspaces`
- `existing_readme` — 기존 README의 path + 글자 수 + 첫 5줄 + **섹션 헤더 목록** (작성자가 추가한 섹션을 보존하는 머지 힌트)
- `tree` — `fd -t f --max-depth 4` 결과 (최대 200줄, 그 이상이면 `…(N more)` 로 truncate)
- `size_warning` — 전체 추적 파일 수 / 핵심 파일 우선순위 적용 여부

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/readme-writer/scripts/scan_repo.sh" "${target_path:-.}"
```

스캔 결과가 빈 레포(파일 0개)이면 즉시 사용자에게 알리고 중단한다 — 의미있는 README를 만들 근거가 없다.

### Step 2: Classify the repo & decide skeleton
**Type**: prompt

스캔 결과를 보고 레포를 5가지 중 하나로 분류한다:

| 분류 | 식별 신호 |
|------|-----------|
| `skill-bundle` | `**/SKILL.md` 다수 존재, 또는 `install.sh`+`bootstrap.sh`가 스킬 심링크를 거는 패턴 |
| `cli-tool` | `package.json`의 `bin`, `pyproject.toml`의 `[project.scripts]`, `Cargo.toml`의 `[[bin]]`, Go의 `main.go`+`cmd/` |
| `library-package` | 매니페스트가 있으나 bin/scripts 없음, PyPI/npm 배포용 메타데이터(license/keywords/repository) 정렬 |
| `webapp` | `next.config.*`, `vite.config.*`, `nuxt.config.*`, `app/` + `pages/`, `Dockerfile` + `docker-compose.yml` |
| `side-script` | 단일 진입점 파일(`main.py`/`index.js`) + 매니페스트 없음, 또는 학습용·일회성 스니펫 |

분류가 모호하면 보수적으로 결정한다 — 잘못된 분류는 어색한 섹션을 강제하여 사용자 신뢰를 깎는다. `references/classification.md`의 섹션 활성화 매트릭스를 참조하여 어떤 섹션을 켤지 결정한다.

monorepo 신호가 감지되면 `AskUserQuestion`으로 다음을 묻는다: "루트 README만 / 각 패키지별 / 둘 다". 사용자 답변에 따라 1개 이상의 README를 차례로 생성한다.

출력 언어는 `language_signal`을 기준으로 결정한다 — 한국어 비율 ≥ 10%이면 ko, 그 외 en (한국어 문서는 영어 코드 블록과 섞이면 비율이 낮게 나오므로 임계값을 낮게 설정). 사용자가 호출 시 언어를 명시했으면 그대로 따른다.

### Step 3: Draft sections
**Type**: prompt + rag

`references/templates/{class}.md`를 로드하여 각 분류에 맞는 섹션 스켈레톤과 톤 가이드를 가져온다. 스켈레톤의 각 섹션을 채울 때 다음 grounding 규칙을 따른다:

- **모든 명령어는 Step 1 결과에 실제로 존재하는 파일에서만 인용한다.** `npm install` 명령은 `package.json`이 있을 때만, `pip install`은 매니페스트 또는 PyPI 메타데이터가 있을 때만 사용한다.
- **모든 환경변수는 `env_signals` (`code_grep` + `shell_grep` + `env_example`)에서 추출한 이름만 적는다.** 코드에 없는 env를 추측해서 추가하지 않는다. shell 스크립트 기반 도구는 `${VAR:-default}` 패턴이 주 신호다.
- **레포 구조 트리는 `scan_repo.sh`의 `tree` 출력을 그대로 사용한다.** 임의로 디렉터리를 생성하지 않는다.
- **트리거 문구는 `skill_triggers[*].description`에서 직접 인용한다.** 데이터 스키마 / 문서 형식 섹션이 필요하면 `skill_triggers[*].schemas` 배열에 추출된 본문을 그대로 인용한다.
- **기존 README의 섹션 헤더(`existing_readme.section_headers`)를 분류 매트릭스와 비교하여, 매트릭스에 없지만 작성자가 추가한 섹션은 "보존 후보"로 표시한다.** Step 5 미리보기에서 사용자에게 "이 섹션도 새 README에 가져올까요?"로 묻는다 — 운영 경험에서 추가된 가치 있는 섹션을 자동 삭제하지 않는다.
- **라이선스 섹션은 `license.spdx` 결과만 사용한다.** 추론 실패면 `[LICENSE - 미지정, 직접 추가 필요]` placeholder를 남긴다.

존재가 확인되지 않은 정보(예: 작성자 이름, GitHub URL)는 매니페스트에서만 가져오며, 없으면 placeholder + `<!-- TODO -->` 주석을 남긴다.

### Step 4: Self-review for grounding & secrets
**Type**: review

`references/self-review.md`의 체크리스트를 적용하여 초안을 검증한다:

1. **Grounding 검증** — README의 모든 셸 명령어, 환경변수 이름, 파일 경로가 Step 1 결과에 실제로 존재하는가? 존재하지 않는 항목이 있으면 해당 줄을 제거하거나 placeholder로 교체한다.
2. **자기완결성 검증** — "새 머신에서 AI 에이전트가 이 README만 보고 설치·사용을 완료할 수 있는가?"를 셀프 시뮬레이션한다. 막히는 지점이 있으면 그 단계 직전 섹션을 보강한다.
3. **Secrets 마스킹** — 본문에서 다음 패턴을 탐지하여 `[REDACTED]`로 치환하고 사용자에게 경고한다:
   - `sk-[A-Za-z0-9_-]{20,}`, `sk-ant-…`, `sk-proj-…`
   - `ghp_…`, `gho_…`, `ghs_…`, `github_pat_…`
   - `xox[baprs]-…`, `AKIA[0-9A-Z]{16}`, `AIza[0-9A-Za-z_-]{30,}`
   - `eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}` (JWT)
   - `.env`/`*.secret`/`*.key` 풀 라인 인용
4. **분류 일관성** — `references/classification.md` 매트릭스에서 비활성으로 표시된 섹션이 본문에 들어가지 않았는지 확인한다.
5. **placeholder 명시** — 본문에 남은 `<!-- TODO -->` 또는 `[…미지정…]`을 README 끝부분 "자동 생성 메타" 섹션에 목록화한다.

문제 발견 시 해당 섹션만 재작성한다 (전체 재작성은 토큰 낭비). 같은 섹션을 2회 이상 재작성하지 않는다.

### Step 5: Preview, confirm, save
**Type**: generate

사용자에게 미리보기를 제시하고 `AskUserQuestion`으로 다음 중 하나를 받는다:

- **저장 (추천)** — 기존 `README.md`가 있으면 `README.md.bak`으로 mv한 뒤 새 파일을 쓴다. 절대경로를 1줄로 보고한다.
- **일부 수정** — 어느 섹션을 어떻게 바꿀지 받아 해당 섹션만 재생성하고 다시 미리보기.
- **취소** — 어떤 파일도 쓰지 않는다.

미리보기는 README 전체를 출력하기보다, 분류 결과 + 활성 섹션 목록 + Step 4에서 발견한 placeholder/TODO 목록을 요약 형태로 먼저 보여준다. 사용자가 "전체 보여줘"라고 하면 전문 출력.

저장 후 마무리 메시지는 1-2줄로 간결하게: 분류, 출력 언어, placeholder 개수, 백업 파일 경로(있을 경우).

## References

- **`references/classification.md`** — 5분류 정의 + 섹션 활성화 매트릭스 (어떤 섹션을 어느 분류에서 켤지의 단일 진실 출처)
- **`references/self-review.md`** — Step 4 체크리스트 (grounding / 자기완결성 / secrets / 분류 일관성)
- **`references/templates/skill-bundle.md`** — Claude Code/Codex 스킬 묶음 레포용 (HandOff 톤)
- **`references/templates/cli-tool.md`** — CLI 도구용 (한 줄 설치 + Usage + 플래그 표)
- **`references/templates/library-package.md`** — npm/PyPI 라이브러리용 (패키지 매니저 설치 + API 예시)
- **`references/templates/webapp.md`** — 웹앱/프로덕트용 (Quick Start + 환경변수 + 배포)
- **`references/templates/side-script.md`** — 사이드 프로젝트/스크립트용 (미니멀)

## Scripts

- **`scripts/scan_repo.sh`** — Step 1 스캐너. 매니페스트/부트스트랩/라이선스/env/언어 시그널을 JSON으로 출력. 인자: 대상 경로 (기본값: `.`).

## Settings

| 설정 | 기본값 | 변경 방법 |
|------|--------|-----------|
| 대상 경로 | cwd | 호출 시 인자로 절대경로 또는 상대경로 전달 |
| 출력 언어 | 자동 감지 | 사용자 호출 시 "영어로 써줘" / "한국어로" 명시 |
| 기존 README 처리 | `.bak` 백업 후 덮어쓰기 | Step 5 미리보기에서 "취소" 선택 |
| monorepo 처리 | 사용자에게 선택지 제시 | Step 2에서 자동 |
| 토큰 한계 처리 | 매니페스트·entrypoint·install 우선 | `scan_repo.sh`에서 50KB 초과 파일은 head 100줄만 |

## Why these design choices

- **Script로 사실, prompt로 글** — 명령어와 환경변수는 추론하면 hallucination이 발생한다. Step 1 스크립트가 사실을 수집하고, Claude는 그걸 인용만 하도록 분리했다.
- **분류 매트릭스 분리** — README 톤이 모든 레포에 한 가지로 강제되면 라이브러리·웹앱에서 어색해진다. 매트릭스를 references로 빼서 분류 추가/조정이 SKILL.md 수정 없이 가능하다.
- **자기검증 단계 필수** — "AI 에이전트가 이것만 보고 설치 가능?" 기준은 사용자가 매번 확인하기 어렵다. Step 4에서 셀프 시뮬레이션을 강제한다.
- **미리보기 먼저, 저장 나중** — README는 한 번 잘못 덮어쓰면 사용자의 작업이 통째로 날아간다. 미리보기 + 백업 + 명시적 확인 3중 안전장치.
- **빈 레포 즉시 중단** — "있는 정보로 어떻게든 만들어보기"는 결국 일반 템플릿이 된다. 정직한 중단이 사용자 신뢰를 지킨다.
