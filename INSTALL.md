# Mirror this Dev Environment

A pure local simulation of the Brain Bridge website (https://brainbridgelabs.ai/).
After running setup you'll have the site running at http://localhost:4321/ with hot reload.

## Prerequisites

- **Node.js 18+** and **npm** — download from https://nodejs.org/
- **Git** — download from https://git-scm.com/

Verify:

```
node --version    # should print v18.x or higher
npm --version
git --version
```

## One-shot setup

Clone the repo, then run the platform-appropriate script.

```
git clone https://github.com/brownsuserid/bb_website_brown_dev.git
cd bb_website_brown_dev
```

**Windows (PowerShell):**

```powershell
.\setup.ps1                # installs deps
.\setup.ps1 -Run           # installs deps and starts the dev server
```

If PowerShell blocks the script, allow it for the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

**macOS / Linux / Git Bash on Windows:**

```bash
chmod +x setup.sh
./setup.sh                 # installs deps
./setup.sh --run           # installs deps and starts the dev server
```

## What the script does

1. Verifies Node.js >= 18 is installed.
2. Runs `npm install` for the site (Astro, Tailwind, Three.js, Lottie, Swiper).
3. If a `cdk/` folder exists, runs `npm install` inside it too (only needed for AWS deploys; failures are non-fatal).
4. Optionally starts the dev server.

## Manual equivalent

If you'd rather not run the script:

```
npm install
npm run dev
```

Then open http://localhost:4321/.

## Common commands

| Command           | Action                                       |
| :---------------- | :------------------------------------------- |
| `npm run dev`     | Start dev server on `localhost:4321` (hot reload) |
| `npm run build`   | Production build to `./dist/`                |
| `npm run preview` | Preview the production build locally         |

The dev script uses `astro dev --host`, so other devices on your LAN can reach the site at `http://<your-ip>:4321/`.

## Troubleshooting

- **Port 4321 already in use** — another dev server is still running. Stop it, or run with a different port: `npx astro dev --port 4322`.
- **`node-gyp` / native build errors on `npm install`** — usually a Node version mismatch. Use Node 20 LTS or 22 LTS for the smoothest experience.
- **`npm audit` warnings** — present in the upstream too; non-blocking for local dev.
