# Template: webapp

웹앱 / 프로덕트용. Next.js, Nuxt, Vite, Remix, Astro 등. Hero 한 줄 + Quick Start + 환경변수 + 배포.

## 권장 섹션 순서

1. **Header** — `# {Product Name}` + Hero 한 줄 (`> A {category} app for {audience}`)
2. **Screenshot placeholder** — `![screenshot](docs/screenshot.png)` (없으면 `<!-- TODO: 스크린샷 추가 -->`)
3. **Quick Start**
   ```bash
   git clone <repo>
   cd <repo>
   {pkg_mgr} install
   cp .env.example .env.local   # 환경변수 채우기
   {pkg_mgr} run dev
   ```
4. **사전 요구사항** — Node 버전, 패키지 매니저(`pnpm` 같이 명시되어 있으면 그대로), DB 등
5. **환경 변수** 표 — `.env.example`에서 그대로 추출
6. **Available Scripts** 표 — `package.json`의 `scripts` 인용
7. **Project Structure** — `app/` / `pages/` / `components/` 같은 핵심 디렉터리 한 줄씩
8. **Development** — 로컬 dev, 테스트, 빌드
9. **Deployment**
   - Vercel/Netlify: deploy 버튼 또는 1-2줄 안내 (`next.config.*` 있으면 Vercel)
   - Docker: `Dockerfile`이 있으면 `docker build … && docker run …`
   - 셀프호스팅: 빌드 → 정적 호스트 / Node 서버
10. **License** (있으면)
11. **자동 생성 메타**

## 톤 가이드

- 영어 / 한국어 모두 OK — 사내 제품이면 한국어, 오픈소스면 영어
- 제품 톤 — 첫 헤더는 마케팅 한 줄 OK (단, 과장은 금지)
- 시각 자료(스크린샷/스크린캐스트)를 placeholder로라도 반드시 포함
- 환경 변수는 표 (이름 / 기본값 / 설명) — `.env.example`이 진실의 출처
- 스크립트는 표 (`scripts`의 키 → 한 줄 설명)

## 인용해야 할 Step 1 결과

| 섹션 | 사용할 데이터 |
|------|---------------|
| Quick Start | `manifests`에서 `package.json`이 있으면 npm/yarn/pnpm 결정 (`pnpm-lock.yaml`이 있으면 pnpm 등) |
| 사전 요구사항 | `package.json`의 `engines.node` |
| 환경 변수 | `env_signals.env_example` 직접 인용, 없으면 `code_grep` 결과에서 변수 이름만 추출 |
| Scripts 표 | `package.json` `scripts` 객체 |
| Deployment | `webapp_signals` (next.config.* → Vercel), `bootstrap`에 `Dockerfile` → Docker, `docker-compose.yml` → docker-compose |

## DO NOT

- 존재하지 않는 데모 URL X — `[demo: TODO]`로
- 스크린샷 파일이 없는데 `![…](docs/screenshot.png)` 적지 말 것 — placeholder 주석으로
- "production-ready in 5 minutes" X — Quick Start 명령이 실제로 동작하면 그게 증명
- 환경변수 값을 절대 그대로 적지 말 것 — `.env.example`에 값이 있어도 README에는 키 + 설명만
