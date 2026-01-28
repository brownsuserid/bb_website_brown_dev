#!/bin/bash
set -e

echo "=========================================="
echo "Building Astro Site"
echo "=========================================="
echo ""

# Check if we're in the project root
if [ ! -f "package.json" ]; then
    echo "ERROR: Must run from project root"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build the site
echo "Building production site..."
npm run build

# Verify build output
if [ ! -d "dist" ]; then
    echo "ERROR: Build failed - dist/ directory not found"
    exit 1
fi

echo ""
echo "✓ Build complete: dist/"
echo "  Files: $(find dist -type f | wc -l | tr -d ' ')"
echo "  Size: $(du -sh dist | cut -f1)"
echo ""
