# Repo Classification & Section Activation Matrix

readme-writer가 레포를 5분류하고 각 분류에 어떤 섹션을 활성화할지 결정하는 단일 출처 문서다.

## 5 Classes

| 분류 | 식별 신호 | HandOff 톤 적용 |
|------|-----------|:---:|
| `skill-bundle` | `**/SKILL.md` 다수, `install.sh`로 `~/.claude/skills/` 심링크, `bootstrap.sh|ps1` 한 줄 설치 | ✅ 기본 ON |
| `cli-tool` | `package.json`의 `bin`, `pyproject.toml`의 `[project.scripts]`, `Cargo.toml`의 `[[bin]]`, Go의 `cmd/{name}/main.go` | △ 부분 적용 |
| `library-package` | 매니페스트 + 메타데이터(license/keywords/repository) 정렬, `bin` 없음, `src/` 또는 `lib/` 위주 | ❌ |
| `webapp` | `next.config.*`, `vite.config.*`, `nuxt.config.*`, `app/`+`pages/`, `Dockerfile`+`docker-compose.yml` | ❌ |
| `side-script` | 단일 진입점 + 매니페스트 없음/최소, `examples/` 위주, 학습용 README 톤 | ❌ |

분류가 모호하면 보수적으로 결정한다. 잘못된 분류는 어색한 섹션을 강제하여 사용자 신뢰를 깎는다. 신호가 충돌하면 우선순위는 `skill-bundle > cli-tool > webapp > library-package > side-script`.

## Section Activation Matrix

| 섹션 | skill-bundle | cli-tool | library-package | webapp | side-script |
|------|:---:|:---:|:---:|:---:|:---:|
| 헤더 (이름 + 한 줄 설명 + 가치 제안) | ✅ | ✅ | ✅ | ✅ | ✅ |
| TL;DR 한 줄 설치 (`curl|bash` / `iwr|iex`) | ✅ | △ | ❌ | ❌ | ❌ |
| AI 에이전트용 설치 가이드 (사전조건/검증/옵션) | ✅ | △ | ❌ | ❌ | ❌ |
| 트리거 문구 (한/영) | ✅ | ❌ | ❌ | ❌ | ❌ |
| 패키지 매니저 설치 (`pip`/`npm`/`cargo`) | ❌ | ✅ | ✅ | ❌ | ❌ |
| Quick Start / 빠른 시작 | ❌ | ✅ | ✅ | ✅ | △ |
| 환경 변수 표 | ✅ | ✅ | △ | ✅ | ❌ |
| Usage / API 예시 | ❌ | ✅ | ✅ | △ | △ |
| 스크린샷 | ❌ | △ | ❌ | ✅ | ❌ |
| 배포 (Vercel/Cloud Run/Docker) | ❌ | ❌ | ❌ | ✅ | ❌ |
| 레포 구조 트리 | ✅ | △ | △ | △ | ❌ |
| 개발 워크플로우 | ✅ | △ | ✅ | ✅ | ❌ |
| 스모크 테스트 / 검증 명령 | ✅ | △ | ✅ | △ | ❌ |
| 라이선스 | ✅ | ✅ | ✅ | ✅ | △ |
| Contributors / Acknowledgements | △ | △ | △ | △ | ❌ |
| Roadmap / Changelog 링크 | △ | △ | ✅ | △ | ❌ |
| 자동 생성 메타 (placeholder/TODO 목록) | ✅ | ✅ | ✅ | ✅ | ✅ |

범례: ✅ 기본 활성 / △ 신호가 있을 때만 활성 / ❌ 비활성 (사용자가 강제로 켜지 않는 한)

## When signals are missing

- 라이선스 파일이 없으면 → 라이선스 섹션을 `[LICENSE - 미지정, 직접 추가 필요]` placeholder로 활성 (분류 매트릭스의 ❌도 이 경우는 안내 한 줄로 활성 가능).
- `git_toplevel`이 null이면 → Contributors / Changelog / 배지 섹션 자동 비활성. README 끝 "자동 생성 메타"에 "git 레포가 아니어서 일부 섹션 생략" 명시.
- 환경변수 신호가 0개이면 → 환경 변수 표 섹션 비활성 (분류 매트릭스에서 ✅이어도).
- 매니페스트가 0개이면 → 패키지 매니저 설치 섹션 비활성, 분류는 `side-script` 가능성 검토.

## Tone Adaptation

- `skill-bundle`: HandOff 톤 그대로. 한 줄 설치, AI 에이전트용 가이드, idempotent 강조.
- `cli-tool`: HandOff 톤 일부만. 한 줄 설치는 `install.sh`/`brew`/`cargo install` 같은 패턴이 있을 때만.
- `library-package`: 차분한 라이브러리 톤. 설치 → import 예시 → API 표 → 라이선스 순서.
- `webapp`: 제품 톤. Hero 한 줄 + 스크린샷 placeholder + Quick Start (`npm i && npm run dev`) + 환경변수 + 배포.
- `side-script`: 미니멀. "이게 뭔지" 한 단락 + "어떻게 실행하는지" 한 단락 + 라이선스 1줄. 너무 무겁게 만들지 않는다.

## Output Language

`scan_repo.sh`의 `language_signal.korean_ratio`로 결정:
- ≥ 0.10 → 한국어
- < 0.30 → 영어

사용자가 호출 시 명시했으면 그대로 따른다 (예: "영어로 써줘", "in English"). 두 언어로 만들고 싶으면 `README.md` + `README.ko.md` (영어 기본)처럼 별도 호출.
