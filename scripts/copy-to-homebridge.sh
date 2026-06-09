#!/bin/bash
#
# Development helper for Homebridge running in Docker (manual copy method).
#
# WARNING: This method is fragile. The Homebridge UI frequently re-installs
# plugins from npm on container restart, overwriting your changes.
#
# Recommended approach: Use a bind mount instead (instructions printed at end of run).
#
# IMPORTANT - Correct usage (especially with Docker + Homebridge UI):
#
# Most people in your situation (UI-managed plugins → root-owned directories)
# will need to use sudo. The script now handles this case intelligently.
#
# Recommended commands:
#   npm run build:deploy:sudo          # Easiest when you need sudo
#   sudo -E npm run build:deploy       # Alternative
#   HOMEBRIDGE_DATA=~/homebridge npm run build:deploy:sudo
#
# Then restart the container.

set -e

# === Configuration ===
# Strongly recommended: Always set this explicitly when using the script.
#
# Correct usage examples:
#   HOMEBRIDGE_DATA=~/homebridge npm run build:deploy
#   HOMEBRIDGE_DATA=/home/ianoberst/homebridge ./scripts/copy-to-homebridge.sh
#
# The script tries to guess using $HOME, but this often fails when running
# as root (common in Docker-related shells), in which case $HOME=/root.

if [ -z "$HOMEBRIDGE_DATA" ]; then
  if [ "$(id -u)" -eq 0 ]; then
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
      # Common case: user ran with sudo because the directory is root-owned
      # (typical when plugins are installed via the Homebridge Docker UI)
      HOMEBRIDGE_DATA="/home/${SUDO_USER}/homebridge"
      echo "==> Detected sudo from user '$SUDO_USER'."
      echo "    Defaulting HOMEBRIDGE_DATA to: ${HOMEBRIDGE_DATA}"
      echo ""
    else
      echo "!!! WARNING: You are running as root (UID 0) but not via sudo from a normal user."
      echo "    \$HOME is /root, so the default would point to /root/homebridge"
      echo "    This is almost certainly NOT where your actual Homebridge data lives."
      echo ""
      echo "    Please run with the correct path explicitly, for example:"
      echo "      HOMEBRIDGE_DATA=~/homebridge npm run build:deploy"
      echo "      # or when using sudo from your normal user:"
      echo "      sudo HOMEBRIDGE_DATA=~/homebridge npm run build:deploy"
      echo ""
      echo "    Aborting to prevent writing to the wrong location."
      exit 1
    fi
  else
    HOMEBRIDGE_DATA="$HOME/homebridge"
  fi
fi

PLUGIN_NAME="homebridge-smartthings-ik"
TARGET_DIR="${HOMEBRIDGE_DATA}/node_modules/${PLUGIN_NAME}"

echo "==> Building plugin..."
npm run build

echo ""
echo "=============================================================="
echo "  Target Homebridge data directory : ${HOMEBRIDGE_DATA}"
echo "  Plugin will be copied to         : ${TARGET_DIR}"
echo "=============================================================="
echo ""

# Sanity check: does this look like a real Homebridge data directory?
if [ ! -f "${HOMEBRIDGE_DATA}/config.json" ]; then
  echo "!!! WARNING: Could not find config.json in ${HOMEBRIDGE_DATA}"
  echo "    This may not be a valid Homebridge data directory."
  echo "    Double-check your HOMEBRIDGE_DATA path."
  echo ""
  read -p "Continue anyway? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo "==> Preparing clean copy into: ${TARGET_DIR}"

# Aggressively remove the old plugin directory to prevent stale files
# (Homebridge UI or previous installs often leave old package.json behind)
if [ -d "${TARGET_DIR}" ]; then
  echo "    Removing existing ${TARGET_DIR} to ensure clean state..."
  rm -rf "${TARGET_DIR}"
fi

mkdir -p "${TARGET_DIR}"

# Core runtime files
cp package.json "${TARGET_DIR}/"
cp config.schema.json "${TARGET_DIR}/"

# Compiled code
cp -r dist "${TARGET_DIR}/"

# Optional but useful
cp LICENSE "${TARGET_DIR}/" 2>/dev/null || true
cp README.md "${TARGET_DIR}/" 2>/dev/null || true

echo ""
echo "✅ Copy complete."
echo ""

# Strong verification
echo "=== Verification of what was actually written ==="
echo "Target directory: ${TARGET_DIR}"
echo ""
echo "package.json in target:"
if [ -f "${TARGET_DIR}/package.json" ]; then
  ls -l "${TARGET_DIR}/package.json"
  echo ""
  echo "Engines + version from the copied file:"
  node -e '
    const pkg = require(process.argv[1]);
    console.log("  version:   ", pkg.version);
    console.log("  homebridge:", pkg.engines?.homebridge || "MISSING");
    console.log("  node:      ", pkg.engines?.node      || "MISSING");
    console.log("  dependencies keys:", Object.keys(pkg.dependencies || {}));
  ' "${TARGET_DIR}/package.json"
else
  echo "  ERROR: package.json was NOT written!"
fi
echo ""
echo "dist directory:"
ls -ld "${TARGET_DIR}/dist" 2>/dev/null || echo "  MISSING"
echo "========================================================"

# Ownership fix for the common Docker UI case (root-owned directories)
if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
  echo ""
  echo "==> You ran this with sudo (as is often required for Docker UI-managed installs)."
  echo "    The copied files are currently owned by root."
  read -p "    Fix ownership of ${TARGET_DIR} to $SUDO_USER? [Y/n] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "    Skipped ownership fix. You may need sudo for future copies."
  else
    echo "    Fixing ownership..."
    chown -R "$SUDO_USER":"$SUDO_USER" "${TARGET_DIR}"
    echo "    Done. Future copies may still require sudo unless you switch to a bind mount."
  fi
fi
echo ""
echo "=== IMPORTANT NOTES ==="
echo ""
echo "1. Restart the container after every copy:"
echo "     docker restart homebridge"
echo ""
echo "2. The Homebridge UI is a common cause of overwrites."
echo "   If you have this plugin installed/managed through the UI, the UI"
echo "   may re-download the published version (1.5.22) on container start."
echo "   Workarounds:"
echo "     - Remove the plugin via the UI first, then use this manual copy method."
echo "     - Or (better long-term) use a bind mount (see below)."
echo ""
echo "3. After restart, hard-refresh the browser (Ctrl+Shift+R)."
echo ""
echo "=== Better long-term development method (recommended) ==="
echo ""
echo "Instead of copying every time, bind-mount your source directly:"
echo ""
echo "In your docker-compose.yml (or docker run -v flags), add:"
echo ""
echo "  volumes:"
echo "    - ~/homebridge:/homebridge"
echo "    - $(pwd):/homebridge/node_modules/${PLUGIN_NAME}"
echo ""
echo "Then you only need to run 'npm run build' on the host."
echo "Changes to dist/ appear immediately inside the container."
echo "You still need to restart Homebridge after changing package.json."
echo ""
echo "This is much more reliable than repeated copies."
echo ""
echo "=== Note on root ownership (your current situation) ==="
echo ""
echo "The root cause of needing sudo is that the Homebridge Docker image + UI"
echo "typically runs as root inside the container. Any plugin installed via the UI"
echo "ends up owned by root on the host."
echo ""
echo "Long-term, the cleanest solution is a bind mount (shown earlier in this output)."
echo "With a bind mount you usually won't need sudo at all for development."
echo ""
echo "=== Correct command going forward ==="
echo ""
echo "  npm run build:deploy:sudo"
echo ""
echo "  or with an explicit path:"
echo "  HOMEBRIDGE_DATA=~/homebridge npm run build:deploy:sudo"
echo "========================================================"