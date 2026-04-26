# Template: cli-tool

CLI 도구용. 설치 → `--help` 출력 기반 Usage → 옵션 표 → 예시. HandOff 톤은 한 줄 설치가 실제로 있을 때만 부분 적용.

## 권장 섹션 순서

1. **Header** — `# {Name}` + 한 줄 설명 (`> A {language} CLI that {does X}`)
2. **Demo (선택)** — asciinema GIF placeholder 또는 30초 사용 예시
3. **Install**
   - 한 줄 설치가 있으면 (`brew install …`, `cargo install …`, `pipx install …`, `curl|sh`) — 그 명령 1-2개
   - 또는 매니페스트별 빌드: `cargo build --release`, `go install ./cmd/{name}`
4. **Quick Start** — 5분 내에 첫 결과를 얻는 예시
5. **Usage**
   - `$ {name} --help` 출력을 그대로 코드 블록에 (또는 entrypoint에서 추출한 서브커맨드 목록)
   - 주요 서브커맨드별 1-2줄 설명
6. **Options / Flags** 표 — 가장 자주 쓰는 것 위주
7. **Configuration** — env 변수, 설정 파일 경로 (있을 때)
8. **Examples** — 3-5개의 현실 시나리오
9. **Development** — `cargo test` / `pytest` / `go test ./...` (선택)
10. **License**
11. **자동 생성 메타**

## 톤 가이드

- 영어 기본 (한국어 비율 ≥ 30%면 한국어로)
- 사용자가 "결과를 빠르게 얻는다" 가 최우선 — Quick Start를 헤더 직후에
- 절대 경로보다 상대 명령 위주 (`./bin/foo` 보다 `foo`)
- 옵션 표는 짧게: `--flag` / 기본값 / 한 줄 설명
- ASCII 입출력 예시 사용 (GIF는 옵션)

## 인용해야 할 Step 1 결과

| 섹션 | 사용할 데이터 |
|------|---------------|
| Header pitch | 매니페스트의 description |
| Install (npm) | `package.json`의 `bin` 필드 → `npm i -g {name}` |
| Install (Python) | `pyproject.toml`의 `[project.scripts]` → `pipx install {name}` |
| Install (Rust) | `Cargo.toml`의 `[[bin]]` → `cargo install {name}` |
| Install (Go) | `go.mod` 모듈 + `cmd/{name}` 디렉터리 → `go install {module}/cmd/{name}@latest` |
| Usage | 가능하면 entrypoint 파일을 읽어 서브커맨드/플래그 추출 |
| Configuration | `env_signals` |

## DO NOT

- 존재하지 않는 패키지 매니저 명령 X (PyPI 등록 안 된 패키지에 `pip install foo` 적지 말 것 — 매니페스트만 있으면 `pipx install git+https://...` 같이 정확히)
- `--help` 출력을 추측하지 말 것 — entrypoint에서 grep할 수 있는 만큼만
- "설치 후 자동으로 동작합니다" 같은 막연한 문구 X — 어떤 명령으로 첫 실행하는지 명시
