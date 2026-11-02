# fit'sin Sales + Targets + Events MVP

## Ecosystem roadmap and cloud handover

See [the Fitsin + Crosstopher programme](docs/ecosystem/README.md) for the saved product plan, performance-first refactor brief, and new-session/cloud handover (2 November 2026).

## What is included

- `backend/` Express API with Shopify + Notion integration, auth, caching, stale fallback
- `ios/` SwiftUI app source + XcodeGen project spec
- `render.yaml` + `backend/Dockerfile` for deployment
- `DEPLOYMENT.md` for release steps

## Quick start (local)

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

Then generate/open iOS project:

```bash
cd ../ios
xcodegen generate
open FitsinMVP.xcodeproj
```
