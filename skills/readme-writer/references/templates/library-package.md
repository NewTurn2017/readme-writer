# Template: library-package

npm/PyPI/cargo crate 등 라이브러리용. 차분한 라이브러리 톤. 설치 → import 예시 → API 표 → 라이선스.

## 권장 섹션 순서

1. **Header** — `# {name}` + 배지 줄 (npm/PyPI/license/CI) + 한 줄 설명
2. **Pitch** — 어떤 문제를 푸는지, 비슷한 라이브러리와의 차이점 (선택, 1-2줄)
3. **Install**
   - npm: `npm install {name}` (또는 `yarn add` / `pnpm add` 함께)
   - PyPI: `pip install {name}` (`uv add`도 옵션으로)
   - cargo: `cargo add {name}` 또는 `Cargo.toml`에 직접 추가하는 예시
4. **Usage** / **Quick Start**
   - 가장 단순한 import + 1개 함수 호출 예시
   - 5-10줄 이내
5. **API** — 주요 함수/클래스 목록. 큰 라이브러리면 표로, 작으면 인라인
6. **Examples** — 2-3개의 현실 시나리오 (각각 코드 펜스)
7. **TypeScript / Type Hints 지원** (선택)
8. **Development** — clone + `npm test` / `pytest` / `cargo test`
9. **Contributing** (CONTRIBUTING.md 있으면 링크)
10. **Changelog** (CHANGELOG.md 있으면 링크)
11. **License**
12. **자동 생성 메타**

## 톤 가이드

- 영어 기본 (다국어 라이브러리는 영어 표준)
- 차분하고 정확한 어조 — 마케팅 X, 사실 위주
- 모든 코드 예시는 *복붙 가능*해야 한다 (가짜 import 경로 X)
- 배지는 실제로 가져올 수 있는 것만 (`shields.io`의 npm/PyPI 배지)

## 인용해야 할 Step 1 결과

| 섹션 | 사용할 데이터 |
|------|---------------|
| Header pitch | 매니페스트의 description |
| 배지 줄 | `manifests[*].content`의 name + version → npm/PyPI/crates 배지 URL 생성 |
| Install | 매니페스트 ecosystem |
| Usage | `package.json` `main`/`module`/`exports`, `pyproject.toml` `[project] name`, `Cargo.toml` `[lib]` |
| API | entrypoint 파일을 보고 export된 심볼 추출 (가능한 만큼) |
| License | `license.spdx` |

## DO NOT

- "production-ready" / "battle-tested" 같은 검증되지 않은 클레임 X
- 한 줄 설치 (`curl | bash`) X — 라이브러리는 패키지 매니저로 설치
- 존재하지 않는 함수/메서드 시그니처 X — entrypoint에서 grep된 것만
- 환경 변수 표는 `env_signals`에 실제 항목이 있을 때만 (라이브러리는 보통 없음)
