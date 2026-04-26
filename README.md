# readme-writer

> 레포의 실제 코드를 직접 읽어 자기완결적인 README.md를 생성하는 Claude Code / Codex CLI 스킬. 새 머신에서 AI 에이전트가 이 README만 보고 설치·사용을 완료할 수 있는 것을 품질 기준으로 삼는다.

템플릿 복붙이 아니다. 매 호출마다 매니페스트(`package.json`/`pyproject.toml`/...)·진입점·환경변수·설치 스크립트를 실제로 읽고, 거기서 grounding한 사실만 README에 쓴다. 추측한 명령어, 존재하지 않는 환경변수, hallucination된 옵션은 자기검증 단계에서 제거된다.

## TL;DR — 한 줄 설치

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/NewTurn2017/readme-writer/main/bootstrap.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/NewTurn2017/readme-writer/main/bootstrap.ps1 | iex
```

### 검증

```bash
ls -l ~/.claude/skills/readme-writer ~/.codex/skills/readme-writer
```

두 줄 모두 `~/.readme-writer/skills/readme-writer` 심링크면 끝. 새 Claude Code/Codex 세션에서 임의의 git 레포로 이동해 "이 레포에 README 써줘" 또는 "write README for this project"를 호출하면 동작한다.

## AI 에이전트용 설치 가이드

새 머신에서 AI 에이전트가 README만 보고 설치를 끝낼 수 있도록 자기완결적으로 적어둔다. 모든 명령은 idempotent — 이미 설치되어 있으면 통과한다.

### 사전 조건

| OS | 필요한 것 |
|----|-----------|
| macOS / Linux | `git`, `bash`, `python3` (시스템 기본) |
| Windows | `git`, `python` (PATH), 심링크용 개발자 모드 또는 관리자 PowerShell. 심링크 실패 시 자동 복사 폴백 |

`~/.claude/skills/` 또는 `~/.codex/skills/` 중 한 쪽이라도 존재해야 한다 (없는 쪽은 자동 스킵). 권장: `fd` / `rg` / `jq` 가 있으면 스캐너가 더 빠르고 정확하다 (없어도 `find`/`grep` 폴백 동작).

### 부트스트랩 환경 변수

| 변수 | 기본값 | 효과 |
|------|--------|------|
| `READMEW_HOME` | `$HOME/.readme-writer` | 레포 클론 위치 |
| `READMEW_REPO` | `https://github.com/NewTurn2017/readme-writer.git` | 포크/미러 사용 시 변경 |
| `READMEW_REF` | `main` | 특정 태그/브랜치 고정 |
| `CLAUDE_SKILLS_DIR` | `$HOME/.claude/skills` | `install.sh`가 링크할 Claude Code 디렉터리 |
| `CODEX_SKILLS_DIR` | `$HOME/.codex/skills` | `install.sh`가 링크할 Codex 디렉터리 |

### 수동 설치

```bash
git clone https://github.com/NewTurn2017/readme-writer.git ~/.readme-writer
cd ~/.readme-writer
./install.sh
```

### `install.sh`가 하는 일

1. `~/.claude/skills/readme-writer` → 이 레포의 `skills/readme-writer` 심링크
2. `~/.codex/skills/readme-writer` → 동일
3. 같은 이름의 실제 폴더가 있으면 `*.backup-YYYYMMDD-HHmmss`로 백업 후 링크로 교체
4. 같은 경로를 가리키는 심링크가 이미 있으면 그대로 둠 (idempotent)

### 옵션

```bash
./install.sh                # 양쪽 디렉터리에 심링크
./install.sh --claude       # ~/.claude/skills 만
./install.sh --codex        # ~/.codex/skills 만
./install.sh --uninstall    # 이 레포가 만든 심링크만 제거 (백업 폴더는 유지)
```

### 업데이트 / 제거

```bash
cd "${READMEW_HOME:-$HOME/.readme-writer}" && git pull          # 업데이트
cd "${READMEW_HOME:-$HOME/.readme-writer}" && ./install.sh --uninstall   # 제거
```

심링크는 그대로이므로 `git pull`만 하면 SKILL.md/스크립트 변경이 즉시 반영된다.

## 스킬 개요

### 트리거 문구

| 한국어 | 영어 |
|--------|------|
| "이 레포에 README 써줘" | "write README" |
| "README 만들어줘" | "generate readme" |
| "리드미 좀 만들어" | "document this repo" |
| "문서화해줘" | "auto-generate readme" |
| "README 자동 생성" | "create readme from scratch" |

`README의 한 줄만 수정해줘` / `README가 뭐야?` 같은 부분 편집 / 개념 질문에는 트리거되지 않는다.

### 5단계 워크플로우

| 단계 | 타입 | 동작 |
|------|------|------|
| 1. 레포 스캔 | script | `scripts/scan_repo.sh`가 매니페스트·부트스트랩·라이선스·env(JS+Python+Shell)·스킬트리거·스키마·언어·monorepo 신호를 JSON으로 수집 |
| 2. 분류 + 골격 결정 | prompt | 5분류 중 하나로 분류, 분류별 섹션 활성화 매트릭스 적용, 출력 언어 자동 감지 |
| 3. 섹션별 초안 | prompt + rag | 분류별 템플릿(`references/templates/{class}.md`) 로드, 모든 명령어/env는 Step 1 결과에서만 인용 |
| 4. 자기검증 | review | grounding · 자기완결성 · secrets 마스킹 · 분류 일관성 · placeholder 6개 체크 |
| 5. 미리보기 + 저장 | generate | 사용자 확인 후 저장, 기존 README는 `.bak`으로 백업 |

### 5분류와 톤

| 분류 | 식별 신호 | HandOff 톤 |
|------|-----------|:---:|
| `skill-bundle` | `**/SKILL.md` 다수, `install.sh`로 `~/.claude/skills/` 심링크 | ✅ 기본 ON |
| `cli-tool` | `package.json` `bin`, `pyproject.toml` `[project.scripts]`, `Cargo.toml` `[[bin]]`, Go의 `cmd/` | △ 부분 |
| `library-package` | 매니페스트 + 메타데이터 정렬, `bin` 없음, `src/` 또는 `lib/` 위주 | ❌ |
| `webapp` | `next.config.*`, `vite.config.*`, `app/`+`pages/`, `Dockerfile` | ❌ |
| `side-script` | 단일 진입점 + 매니페스트 없음/최소 | ❌ |

분류가 모호하면 보수적으로 결정한다 — 잘못된 분류는 어색한 섹션을 강제하여 사용자 신뢰를 깎는다. 신호 충돌 시 우선순위는 `skill-bundle > cli-tool > webapp > library-package > side-script`. 자세한 매트릭스는 [`skills/readme-writer/references/classification.md`](skills/readme-writer/references/classification.md) 참고.

### 출력 언어

`scan_repo.sh`의 `language_signal.korean_ratio`로 결정 — ≥ 10%이면 한국어, 그 외 영어. 사용자가 호출 시 명시했으면 그대로 따른다 ("영어로 써줘" / "in English").

## 자기검증 기준 (Step 4)

생성된 README는 미리보기 전에 다음 6개 항목을 자체 통과해야 한다:

1. **Grounding** — 모든 명령어/환경변수/경로가 Step 1 결과에 실제로 존재하는가?
2. **Self-completability** — 새 머신에서 AI 에이전트가 이 README만 보고 설치·사용을 완료할 수 있는가? 셀프 시뮬레이션.
3. **Secrets 마스킹** — `sk-…`, `ghp_…`, `AKIA…`, JWT, 개인키 블록, `*_KEY=` 등 패턴을 `[REDACTED]`로 치환.
4. **분류 일관성** — 매트릭스에서 비활성으로 표시된 섹션이 본문에 들어가지 않았는가?
5. **Placeholder 명시** — 남은 `<!-- TODO -->` / `[…미지정…]`을 README 끝 "자동 생성 메타" 섹션에 목록화.
6. **재작성 1회 제한** — 같은 섹션을 같은 호출에서 2회 이상 재작성하지 않음. 토큰 낭비 방지.

자세한 체크리스트는 [`skills/readme-writer/references/self-review.md`](skills/readme-writer/references/self-review.md) 참고.

## 레포 구조

```
readme-writer/
├── README.md
├── LICENSE
├── install.sh                              # ~/.claude, ~/.codex 양쪽 심링크 설치
├── bootstrap.sh / bootstrap.ps1            # curl|bash / iwr|iex 한 줄 설치
└── skills/
    └── readme-writer/
        ├── SKILL.md                        # 5단계 워크플로우 + Settings + Why these design choices
        ├── scripts/
        │   └── scan_repo.sh                # Step 1 스캐너 (bash 3.2 호환, fd/rg→find/grep 폴백)
        └── references/
            ├── classification.md           # 5분류 + 16섹션 활성화 매트릭스
            ├── self-review.md              # Step 4 체크리스트
            └── templates/
                ├── skill-bundle.md         # HandOff 톤
                ├── cli-tool.md
                ├── library-package.md
                ├── webapp.md
                └── side-script.md
```

## 개발 워크플로우

이 레포가 Claude Code / Codex 양쪽이 실제로 로드하는 파일의 단일 출처. 별도 빌드/배포 없음.

1. `skills/readme-writer/SKILL.md` 또는 `skills/readme-writer/{scripts,references}/*` 수정
2. 수정 즉시 `~/.claude/skills/readme-writer`와 `~/.codex/skills/readme-writer`에 반영 (심링크)
3. 새 Claude Code/Codex 세션을 임의의 git 레포에서 띄워 "README 써줘" 호출 → 변경 동작 확인
4. 커밋 & 푸시

### 수동 스모크 테스트

```bash
# Step 1 스캐너 단독 실행 (현재 cwd 또는 인자로 받은 경로)
bash skills/readme-writer/scripts/scan_repo.sh /path/to/repo | jq

# 스캐너 핵심 신호만 빠르게 확인
bash skills/readme-writer/scripts/scan_repo.sh /path/to/repo | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('manifests:', [m['file'] for m in d['manifests']])
print('bootstrap:', [b['file'] for b in d['bootstrap']])
print('license:', d['license']['spdx'])
print('skill_triggers:', len(d['skill_triggers']))
print('shell env vars:', len(d['env_signals']['shell_grep']))
print('ko_ratio:', d['language_signal']['korean_ratio'])
"
```

스캐너 단독 출력만 봐도 분류와 활성 섹션이 어떻게 결정될지 예측 가능하다.

## 라이선스

MIT — [LICENSE](LICENSE) 참고.

## Credits

`skillers-suda` 스킬 패널(기획자 / 사용자 / 전문가 / 검수자)의 토론을 기반으로 [HandOff](https://github.com/NewTurn2017/HandOff) 패턴에 맞춰 작성. 설계·구현: [@NewTurn2017](https://github.com/NewTurn2017).
