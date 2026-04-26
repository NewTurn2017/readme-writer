# Template: side-script

사이드 프로젝트 / 학습용 스크립트 / 일회성 도구. 미니멀. 너무 무겁게 만들지 않는다.

## 권장 섹션 순서

1. **Header** — `# {Name}` + 한 줄 설명
2. **What it does** (1 단락, 3-5줄) — 어떤 문제를 풀려고 만들었는지
3. **How to run** — 1-3줄 명령
   - Python: `python main.py` 또는 `uv run main.py`
   - Node: `node index.js`
   - Bash: `./run.sh`
4. **Notes** (선택) — 알려진 한계, 일회성이라는 명시 ("Quick hack to scratch an itch")
5. **License** (있을 때만, 또는 한 줄로 "MIT" / "no license — personal project")

## 톤 가이드

- 한국어 / 영어 / 그 무엇도 OK — 작성자 편의
- 격식 X. 친근하고 솔직하게.
- 설치 한 줄 X, AI 에이전트용 가이드 X, 트리거 문구 X — 이건 사이드 프로젝트다
- 4-5섹션 이내, 200줄 이내가 목표
- placeholder 자동 생성 메타 섹션 *생략* 가능 (대신 사용자에게 콘솔로만 보고)

## 인용해야 할 Step 1 결과

| 섹션 | 사용할 데이터 |
|------|---------------|
| Header pitch | 매니페스트가 있으면 description, 없으면 entrypoint 파일의 첫 docstring/주석 |
| How to run | 매니페스트 또는 진입점 파일명 |

## DO NOT

- 환경 변수 표 X (`env_signals`가 비어있다면)
- 라이선스 섹션 강제 X — `license.spdx`가 unknown이면 한 줄 "MIT 추천 / 라이선스 미정"으로 끝
- TL;DR 한 줄 설치 X
- "Built with ❤️" 같은 클리셰 X
- 가짜 배지 X (CI 없는데 CI 배지 적지 말 것)

## 분류가 애매할 때

side-script는 *디폴트 fallback*에 가깝다. 다음 중 하나라도 강하게 해당하면 분류를 다시 고려:
- 매니페스트가 정상적으로 정렬되어 있고 license/keywords가 있다 → `library-package`
- `bin` / `[[bin]]` / `[project.scripts]`가 있다 → `cli-tool`
- `next.config.*` 등 웹 프레임워크 설정이 있다 → `webapp`
- `**/SKILL.md`가 있다 → `skill-bundle`

위 어느 것도 해당 안 되고 단일 진입점만 있을 때 — 그때만 진짜 `side-script`다.
