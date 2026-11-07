#!/usr/bin/env bash
#
# Install the BulkDeleteDm and FloodDM plugins into a Vencord install.
#
# Vencord has no runtime plugin folder, so a user plugin has to be
# compiled into the Vencord bundle. This script does that for you:
#
#   1. clone Vencord at the version you already run
#   2. fetch both plugins into src/userplugins/
#   3. build once
#   4. install the result over your current Vencord
#
# Both plugins land in the same bundle in a single build, so neither one
# removes the other.
#
# Usage:
#   ./install.sh                     # auto-detect the install type
#   ./install.sh --standalone        # Discord for Mac (standalone Vencord)
#   ./install.sh --regular           # regular Vencord (Windows/Linux/Mac installer)
#   ./install.sh --help
#
# Environment overrides:
#   VENCORD_CLONE          where to keep the Vencord checkout
#   VENCORD_USER_DATA_DIR  where the Vencord install lives
#

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${VENCORD_CLONE:-$HOME/vencord-dm-plugins-build}"
REPO="https://github.com/Vendicated/Vencord.git"
MODE="auto"

# The plugins to install. Each entry is:
#   display name | directory under src/userplugins | repo | fallback tag
#
# The tag is only a fallback. The latest release of each repo is used when
# the GitHub API can be reached, so a new plugin release is picked up
# without touching this script.
#
#   name          dir              repo                                        tag
PLUGINS=(
    "BulkDeleteDm|bulkDeleteDm|https://github.com/Harishisonline/vencord-bulk-delete-dm.git|v2.2.0"
    "FloodDM|floodDm|https://github.com/Harishisonline/vencord-flood-dm.git|v1.0.0"
)

while [ $# -gt 0 ]; do
    case "$1" in
        --standalone) MODE="standalone" ;;
        --regular) MODE="regular" ;;
        --help|-h)
            # Print the header comment block, stopping at the first
            # non-comment line.
            sed -n '2,/^[^#]/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' | sed '$d'
            exit 0
            ;;
        *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
    esac
    shift
done

command -v git >/dev/null || { echo "ERROR: git is required" >&2; exit 1; }
command -v node >/dev/null || { echo "ERROR: node is required" >&2; exit 1; }
command -v pnpm >/dev/null || { echo "ERROR: pnpm is required (https://pnpm.io/installation)" >&2; exit 1; }

# ---------------------------------------------------------------- detect ----
DATA_DIR="${VENCORD_USER_DATA_DIR:-$HOME/Library/Application Support/Vencord}"

if [ "$MODE" = "auto" ]; then
    if [ -d "$DATA_DIR/dist" ]; then
        MODE="standalone"
    else
        MODE="regular"
    fi
    echo "==> Detected install type: $MODE"
fi

# ----------------------------------------------------------------- clone ----
if [ ! -d "$CLONE/.git" ]; then
    echo "==> Cloning Vencord into $CLONE"
    git clone "$REPO" "$CLONE"
fi

cd "$CLONE"

# Rebuild against the exact Vencord version the user already runs, so the
# result differs only by these plugins. The standalone bundle embeds its
# version as `Vencord:` + backtick + `v1.15.16`. Note the backtick, a plain
# grep for "Vencord v1.15.16" does NOT match.
TARGET_VERSION=""
if [ "$MODE" = "standalone" ] && [ -f "$DATA_DIR/dist/renderer.js" ]; then
    TARGET_VERSION="$(grep -oE 'Vencord:`v[0-9]+\.[0-9]+\.[0-9]+' "$DATA_DIR/dist/renderer.js" 2>/dev/null | head -1 | sed 's/^Vencord:`//' || true)"
fi

git fetch --all --tags --quiet

if [ -n "$TARGET_VERSION" ] && git rev-parse -q --verify "refs/tags/$TARGET_VERSION" >/dev/null; then
    echo "==> Using Vencord $TARGET_VERSION (matches your installed build)"
    git checkout --quiet "refs/tags/$TARGET_VERSION"
elif [ -n "$TARGET_VERSION" ]; then
    echo "==> Vencord $TARGET_VERSION not found as a tag, using latest instead"
    git checkout --quiet origin/main
else
    echo "==> Using latest Vencord ($(git rev-parse --short origin/main))"
    git checkout --quiet origin/main
fi

# --------------------------------------------------------------- plugins ----
# src/userplugins is gitignored in Vencord, so anything already in this
# checkout survives the checkout above and gets built again. That is what
# makes the individual plugin installers compose with this one.
resolve_tag() {
    # $1 = repo url, $2 = fallback tag
    if command -v curl >/dev/null; then
        local slug
        slug="${1%.git}"
        slug="${slug#https://github.com/}"
        local tag
        tag="$(curl -fsSL "https://api.github.com/repos/$slug/releases/latest" 2>/dev/null \
            | grep -m1 '"tag_name"' \
            | sed 's/.*"tag_name": *"//; s/".*//' || true)"
        if [ -n "$tag" ]; then
            echo "$tag"
            return
        fi
    fi
    echo "$2"
}

PLUGIN_SRC_DIR="$(mktemp -d)"
trap 'rm -rf "$PLUGIN_SRC_DIR"' EXIT

for entry in "${PLUGINS[@]}"; do
    IFS='|' read -r name dir repo fallback_tag <<< "$entry"

    tag="$(resolve_tag "$repo" "$fallback_tag")"

    echo "==> Fetching $name ($tag)"
    fetch_dir="$PLUGIN_SRC_DIR/$dir"
    rm -rf "$fetch_dir"
    if ! git clone --quiet --depth 1 --branch "$tag" "$repo" "$fetch_dir" 2>/dev/null; then
        echo "    release $tag not found, falling back to the default branch"
        rm -rf "$fetch_dir"
        git clone --quiet --depth 1 "$repo" "$fetch_dir"
    fi

    src="$fetch_dir/src/userplugins/$dir/index.tsx"
    if [ ! -f "$src" ]; then
        echo "ERROR: $name source not found at src/userplugins/$dir/index.tsx in $repo" >&2
        exit 1
    fi

    mkdir -p "src/userplugins/$dir"
    cp "$src" "src/userplugins/$dir/index.tsx"
done

# ----------------------------------------------------------------- build ----
if [ ! -d node_modules ]; then
    echo "==> Installing dependencies (this takes a few minutes)"
    pnpm install --frozen-lockfile
fi

echo "==> Building Vencord (this takes a few minutes)"
if [ "$MODE" = "standalone" ]; then
    pnpm build --standalone
else
    pnpm build
fi

# ---------------------------------------------------------------- install --
if [ "$MODE" = "standalone" ]; then
    DIST="$DATA_DIR/dist"
    [ -d "$DIST" ] || { echo "ERROR: $DIST not found" >&2; exit 1; }

    echo "==> Backing up current renderer"
    cp -p "$DIST/renderer.js" "$DIST/renderer.js.bak"
    [ -f "$DIST/renderer.js.map" ] && cp -p "$DIST/renderer.js.map" "$DIST/renderer.js.map.bak" || true

    # The bundle is replaced as a whole. Anything that was in the old
    # bundle but is not in this build is about to disappear, so say so
    # rather than letting the user discover it.
    INSTALLED_PLUGINS="$(grep -oE 'userplugins/[a-zA-Z0-9_-]+' "$DIST/renderer.js" 2>/dev/null \
        | sed 's|userplugins/||' | sort -u || true)"
    if [ -n "$INSTALLED_PLUGINS" ]; then
        DROPPED=""
        for p in $INSTALLED_PLUGINS; do
            [ -d "src/userplugins/$p" ] || DROPPED="$DROPPED $p"
        done
        if [ -n "$DROPPED" ]; then
            echo ""
            echo "WARNING: these custom plugins are in your current bundle but are"
            echo "not in this build, so they will be removed:"
            for p in $DROPPED; do echo "    $p"; done
            echo ""
        fi
    fi

    echo "==> Installing"
    cp -p dist/renderer.js "$DIST/renderer.js"
    cp -p dist/renderer.js.map "$DIST/renderer.js.map" 2>/dev/null || true
    cp -p dist/renderer.js.LEGAL.txt "$DIST/renderer.js.LEGAL.txt" 2>/dev/null || true

    # Verify both plugins actually made it into the installed bundle.
    for entry in "${PLUGINS[@]}"; do
        IFS='|' read -r name dir repo fallback_tag <<< "$entry"
        if grep -q "userplugins/$dir" "$DIST/renderer.js" 2>/dev/null; then
            echo "    verified: $name"
        else
            echo "ERROR: $name is missing from the installed bundle" >&2
            exit 1
        fi
    done

    cat <<EOF

==> Done. Restart Discord (Cmd+Q, then reopen).

    Both plugins are now installed:
        BulkDeleteDm  delete your own messages from a DM in bulk
        FloodDM       send a message many times in a DM

    Note: Vencord's auto-updater replaces renderer.js with the official
    build, which does not contain these plugins. Re-run this script after
    a Vencord update.

EOF
else
    echo "==> Installing into Discord via the Vencord installer"
    pnpm inject

    cat <<EOF

==> Done. Restart Discord.

    Both plugins are now installed:
        BulkDeleteDm  delete your own messages from a DM in bulk
        FloodDM       send a message many times in a DM

    Note: if Vencord auto-updates, re-run this script to rebuild.

EOF
fi
