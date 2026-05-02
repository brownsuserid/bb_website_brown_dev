#!/usr/bin/env bash
# Mirror this Brain Bridge web dev environment on a fresh machine.
# Usage: ./setup.sh           install deps only
#        ./setup.sh --run     install deps and start dev server
set -euo pipefail

REQUIRED_NODE_MAJOR=18

command -v node >/dev/null 2>&1 || { echo "ERROR: Node.js not found. Install Node 18+ from https://nodejs.org/"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "ERROR: npm not found (should ship with Node.js)."; exit 1; }

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "${NODE_MAJOR}" -lt "${REQUIRED_NODE_MAJOR}" ]; then
  echo "ERROR: Node ${REQUIRED_NODE_MAJOR}+ required, found $(node --version)"; exit 1
fi

echo "Node $(node --version) / npm $(npm --version) detected."
echo "Installing site dependencies (this can take a minute)..."
npm install

if [ -d cdk ]; then
  echo "Installing CDK dependencies (optional, only needed for AWS deploys)..."
  ( cd cdk && npm install ) || echo "WARN: cdk install failed; this is fine if you only want to run the site locally."
fi

echo
echo "Done."
echo "Start the dev server with: npm run dev"
echo "It will be available at: http://localhost:4321/"

if [ "${1-}" = "--run" ]; then
  echo
  echo "Starting dev server..."
  exec npm run dev
fi
