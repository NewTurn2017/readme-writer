# Self-Review Checklist (Step 4)

readme-writer가 미리보기 전에 초안을 검증할 때 적용하는 체크리스트다. 각 항목은 실패 시 어떤 수정을 할지 명시한다.

## 1. Grounding 검증

README의 모든 셸 명령어, 환경변수 이름, 파일 경로가 Step 1 (`scan_repo.sh`) 결과에 실제로 존재하는지 확인한다.

| 항목 | 검사 방법 | 실패 시 |
|------|-----------|---------|
| `curl … bootstrap.sh \| bash` | `bootstrap.sh`가 `bootstrap` 배열에 있는가? | 한 줄 설치 줄 제거 |
| `iwr … bootstrap.ps1 \| iex` | `bootstrap.ps1`이 `bootstrap` 배열에 있는가? | Windows 줄 제거 |
| `npm install <pkg>` | `package.json`이 `manifests`에 있는가? | 줄 제거 또는 `pip`/`cargo`로 교체 |
| `pip install <pkg>` | `pyproject.toml` 또는 `setup.py`가 있는가? | 줄 제거 |
| 환경변수 `XXX_TOKEN` | `env_signals.code_grep` / `shell_grep` / `env_example` 셋 중 하나에서 발견됐는가? | 행 제거 |
| Shell `${VAR:-default}` 변수 | `env_signals.shell_grep` 에 있는가? | 행 제거 |
| 트리거 문구 | `skill_triggers[*].description` 에서 직접 인용했는가? | 추측 트리거 제거 |
| 데이터 스키마 / 문서 형식 블록 | `skill_triggers[*].schemas` 의 본문을 인용했는가? | placeholder로 교체 또는 제거 |
| 기존 README 섹션 보존 | `existing_readme.section_headers` 중 매트릭스에 없는 것을 사용자에게 확인했는가? | Step 5 미리보기에서 묻기 |
| 라이선스 (MIT/Apache) | `license.spdx`와 일치? | placeholder로 교체 |
| `git clone <url>` | `git.remote`가 비어있지 않은가? | placeholder로 교체 |
| 디렉터리 구조 트리 | `tree` 출력과 일치? | 트리 재생성 |

존재가 확인되지 않은 항목은 **추측해서 채우지 말고** placeholder + `<!-- TODO -->` 주석을 남긴다.

## 2. Self-Completability Simulation

"새 머신에서 AI 에이전트가 이 README만 보고 설치·사용을 완료할 수 있는가?"를 셀프 시뮬레이션한다. 다음 질문을 차례로 답한다:

1. 사전 조건이 명확한가? (필요한 OS / 런타임 / 도구가 표 또는 단락으로 명시)
2. 한 줄로 설치 시작 가능한가? (또는 `clone → install` 두 단계가 명확한가)
3. 설치 직후 검증 명령이 있는가? (`ls -l …` / `--version` / smoke test)
4. 첫 사용 예시(Quick Start)가 있는가?
5. 환경 변수가 필요하다면 표로 정리되어 있고 기본값/설명이 있는가?
6. 실패 케이스(가장 흔한 한두 개)에 대한 안내가 있는가?
7. 업데이트 / 제거 방법이 있는가? (장기 사용 가능성 시그널)

막히는 지점이 있으면 그 단계 직전 섹션을 보강한다. 막히는 지점이 *분류 매트릭스에서 비활성된 섹션* 때문이면, 매트릭스 결정이 옳은지 재검토 — 분류가 잘못된 신호일 수 있다.

## 3. Secrets 마스킹

README 본문에서 다음 패턴을 정규식으로 탐지한다. 발견 시 `[REDACTED]`로 치환하고, 사용자에게 "secret-looking value를 마스킹했음"을 마무리 메시지에 한 줄로 알린다.

```
sk-[A-Za-z0-9_-]{20,}
sk-ant-[A-Za-z0-9_-]{20,}
sk-proj-[A-Za-z0-9_-]{20,}
ghp_[A-Za-z0-9]{20,}
gho_[A-Za-z0-9]{20,}
ghs_[A-Za-z0-9]{20,}
github_pat_[A-Za-z0-9_]{30,}
xox[baprs]-[A-Za-z0-9-]{10,}
AKIA[0-9A-Z]{16}
AIza[0-9A-Za-z_-]{30,}
hf_[A-Za-z0-9]{30,}
rk_live_[A-Za-z0-9]{20,}
sk_live_[A-Za-z0-9]{20,}
eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}
-----BEGIN [A-Z ]*PRIVATE KEY-----
```

추가로 `*_KEY=`, `*_TOKEN=`, `*_SECRET=`, `*_PASSWORD=`, `*_PWD=` 형태의 env 할당이 README에 풀 값으로 노출되어 있으면 값 부분을 `[REDACTED]`로 치환.

`.env`/`.env.local`/`*.pem` 파일의 *내용 인용*은 README에 절대 포함하지 않는다 — 환경변수의 *이름*만 표에 적는다.

## 4. 분류 일관성

`references/classification.md`의 매트릭스에서 "비활성(❌)"으로 표시된 섹션이 본문에 들어가지 않았는지 확인한다. 들어갔다면 다음 중 하나로 처리:

- 사용자가 명시적으로 요청한 섹션이면 그대로 둠 (예: "스크린샷 섹션도 넣어줘")
- 그렇지 않으면 제거

"신호 있을 때만(△)" 섹션은 `scan_repo.sh` 결과에서 해당 신호가 실제로 발견됐는지 확인. 없으면 제거.

## 5. Placeholder / TODO 목록화

본문에 남은 다음 패턴을 모두 수집:
- `<!-- TODO: ... -->`
- `[…미지정…]` / `[TBD]` / `[FIXME]`
- 명확히 추론된 빈 값 (예: `version: ""`)

수집된 목록을 README 끝에 "## 자동 생성 메타" 섹션으로 추가한다 (또는 사용자에게만 보고하고 본문에서 제외 — 분류가 `side-script`일 때 권장).

```markdown
## 자동 생성 메타

이 README는 readme-writer 스킬이 자동 생성했습니다. 다음 항목은 수동 보완이 필요해요:

- [ ] {placeholder 1}
- [ ] {placeholder 2}
```

## 6. 재작성 정책

- 한 섹션을 같은 호출에서 **2회 이상 재작성하지 않는다**. 두 번째 재작성에서도 grounding 위반이 발견되면 그 섹션을 제거하거나 placeholder로 남긴다.
- 전체 README를 재작성하지 않는다 — 토큰 낭비. 문제가 발견된 섹션만 손본다.
- 재작성으로 해결 안 되는 항목은 "자동 생성 메타"에 명시하여 사용자가 수동 처리하도록 위임한다.
