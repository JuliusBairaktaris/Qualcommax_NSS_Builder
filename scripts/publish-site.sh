#!/usr/bin/env bash
# Rebuild gh-pages: the image picker (site/), one directory per release with
# its kmod feeds (<tag>/<group>/), and the indexes the picker and ppe-update
# read (releases.json, <tag>/boards.json). Directories of deleted releases go.
#
# Required env:
#   REPO      owner/name
#   PREFIX    release tag prefix (ppe-nss)
#   GH_TOKEN  push access
# Optional:
#   NEW_DIR   directory holding <tag>/<group>/ trees to add (the feed artifacts)
#   SITE_DIR  the picker sources (default: site/ next to this script)
#   PAGES_REPO, PAGES_URL, PAGES_DEPLOY_KEY
#             publish to the default branch of PAGES_REPO (a <name>.github.io
#             repository) with this deploy key instead; this repository's
#             gh-pages then only points there, for images that name it

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

: "${REPO:?}" "${PREFIX:?}" "${GH_TOKEN:?}"
SITE_DIR="${SITE_DIR:-$(dirname -- "$0")/../site}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

own="https://x-access-token:${GH_TOKEN}@github.com/${REPO}"
if [[ -n "${PAGES_DEPLOY_KEY:-}" ]]; then
  : "${PAGES_REPO:?}" "${PAGES_URL:?}"
  (umask 077; printf '%s\n' "$PAGES_DEPLOY_KEY" >"$work/key")
  export GIT_SSH_COMMAND="ssh -i $work/key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  target="git@github.com:${PAGES_REPO}.git"
  branch=main
else
  target="$own"
  branch=gh-pages
fi

if git ls-remote --exit-code --heads "$target" "$branch" >/dev/null; then
  git clone -q --depth 1 --branch "$branch" "$target" "$work/site"
else
  git init -q -b "$branch" "$work/site"
fi

gh release list --repo "$REPO" --limit 100 --exclude-drafts \
  --json tagName,publishedAt >"$work/releases.raw.json"

shopt -s nullglob
for d in "$work"/site/*/; do
  t="$(basename "$d")"
  jq -e --arg t "$t" 'any(.[]; .tagName == $t)' "$work/releases.raw.json" >/dev/null ||
    { log::info "dropping $t"; rm -rf "$d"; }
done
[[ -n "${NEW_DIR:-}" ]] && cp -a "$NEW_DIR"/. "$work/site/"
rsync -a --delete --exclude '/*/' --exclude '/.git' "$SITE_DIR"/ "$work/site/"
touch "$work/site/.nojekyll"

python3 - "$work/site" "$work/releases.raw.json" "$PREFIX" <<'EOF'
import json, os, re, sys
from datetime import datetime

root, raw, prefix = sys.argv[1:]
pat = re.compile(re.escape(prefix) + r"-\d{8}T\d{6}Z-\d+$")
rels = []
for r in json.load(open(raw)):
    tag = r["tagName"]
    d = os.path.join(root, tag)
    if not pat.match(tag) or not os.path.isdir(d):
        continue
    boards = []
    for group in sorted(os.listdir(d)):
        g = os.path.join(d, group)
        pf = os.path.join(g, "profiles.json")
        if not os.path.isfile(pf):
            continue
        prof = json.load(open(pf))
        for pid, p in prof["profiles"].items():
            img = next((i for i in p["images"] if i["type"] == "sysupgrade"), None)
            if not img:
                continue
            man = os.path.join(g, p["image_prefix"] + ".manifest")
            dev = []
            if not os.path.isfile(man):
                # Per-device rootfs builds write one manifest for the group;
                # each image adds its device packages to it.
                man = os.path.join(g, p["image_prefix"].removesuffix("-" + pid) + ".manifest")
                dev = p.get("device_packages", [])
            pkgs = []
            if os.path.isfile(man):
                pkgs = {l.split(" - ")[0] for l in open(man) if " - " in l}
                pkgs |= {d for d in dev if not d.startswith("-")}
                pkgs = sorted(pkgs - {d[1:] for d in dev if d.startswith("-")})
            for board in p["supported_devices"]:
                boards.append({
                    "board": board, "group": group, "profile": pid,
                    "titles": [" ".join(x for x in (t.get("vendor"), t.get("model"),
                                                     t.get("variant")) if x) or t.get("title", "")
                               for t in p["titles"]],
                    "image": img["name"], "sha256": img["sha256"], "size": img["size"],
                    "packages": pkgs,
                })
    json.dump(boards, open(os.path.join(d, "boards.json"), "w"), separators=(",", ":"))
    t = int(datetime.fromisoformat(r["publishedAt"].replace("Z", "+00:00")).timestamp())
    rels.append({"tag": tag, "time": t,
                 "groups": sorted({b["group"] for b in boards})})
rels.sort(key=lambda r: r["tag"], reverse=True)
json.dump({"latest": rels[0]["tag"] if rels else "", "releases": rels},
          open(os.path.join(root, "releases.json"), "w"), indent=1)
print(f"{len(rels)} releases indexed")
EOF

# One orphan commit, so deleted feeds leave the repository too.
push() {
  git -C "$1" checkout -q --orphan pages-new
  git -C "$1" add -A
  git -C "$1" -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit -q -m "$2"
  git -C "$1" push -q --force "$3" "pages-new:$4"
}
push "$work/site" "Publish the image picker and the kmod feeds" "$target" "$branch"
log::info "published to ${PAGES_REPO:-$REPO} $branch"

if [[ -n "${PAGES_DEPLOY_KEY:-}" ]]; then
  mkdir "$work/stub"
  git -C "$work/stub" init -q -b gh-pages
  printf '{"moved": "%s", "latest": "", "releases": []}\n' "$PAGES_URL" >"$work/stub/releases.json"
  printf '<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=%s/"><a href="%s/">%s</a>\n' \
    "$PAGES_URL" "$PAGES_URL" "$PAGES_URL" >"$work/stub/index.html"
  touch "$work/stub/.nojekyll"
  push "$work/stub" "Point to $PAGES_URL" "$own" gh-pages
  log::info "gh-pages points to $PAGES_URL"
fi
