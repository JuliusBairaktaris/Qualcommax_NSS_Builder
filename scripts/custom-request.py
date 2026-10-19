#!/usr/bin/env python3
"""Turn a custom-build issue into ImageBuilder arguments.

Reads the issue from $GITHUB_EVENT_PATH and the release indexes from
$SITE_URL, writes tag, group, profile, packages and title to $GITHUB_OUTPUT
and the requested uci-defaults script to $UCI_DEFAULTS_OUT. Every field is
untrusted: anything that does not validate stops the build with a reason,
which is printed for the issue comment.
"""
import json
import os
import re
import sys
import urllib.request

PKG = re.compile(r"^[a-z0-9][a-z0-9+._-]{0,63}$")
FIELDS = {"Device": "device", "Release": "release", "Add packages": "add",
          "Remove packages": "remove", "First-boot script (uci-defaults)": "script"}
MAX_PKGS = 200
MAX_SCRIPT = 16384


def fail(msg):
    msg = " ".join(msg.split())[:300]
    print(msg)
    with open(os.environ["GITHUB_OUTPUT"], "a") as f:
        f.write(f"error={msg}\n")
    sys.exit(1)


def sections(body):
    out, key = {}, None
    for line in body.replace("\r\n", "\n").split("\n"):
        m = re.match(r"^### (.+?)\s*$", line)
        if m:
            key = FIELDS.get(m.group(1))
            if key:
                out[key] = []
            continue
        if key:
            out[key].append(line)
    res = {}
    for k, v in out.items():
        text = "\n".join(v).strip()
        if text.startswith("```"):
            text = re.sub(r"^```[a-z]*\n?", "", text)
            text = re.sub(r"\n?```$", "", text)
        res[k] = "" if text == "_No response_" else text
    return res


def fetch(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)


def pkgs(text, what):
    names = text.replace(",", " ").split()
    for n in names:
        if not PKG.match(n):
            fail(f"'{n}' in {what} is not a package name")
    return names


def main():
    issue = json.load(open(os.environ["GITHUB_EVENT_PATH"]))["issue"]
    f = sections(issue.get("body") or "")
    site = os.environ["SITE_URL"]

    m = re.match(r"^([A-Za-z0-9_-]+)/([A-Za-z0-9_,.-]+)$", f.get("device", ""))
    if not m:
        fail("Device must be <group>/<profile>, as the image picker fills it in.")
    group, profile = m.groups()

    rels = fetch(f"{site}/releases.json")
    if rels.get("moved"):
        site = rels["moved"]
        rels = fetch(f"{site}/releases.json")
    tag = f.get("release") or rels["latest"]
    if tag not in {r["tag"] for r in rels["releases"]}:
        fail(f"Release '{tag}' is not available any more; pick the device again in the image picker.")

    boards = fetch(f"{site}/{tag}/boards.json")
    entry = next((b for b in boards if b["group"] == group and b["profile"] == profile), None)
    if not entry or not entry["packages"]:
        fail(f"{tag} has no image for {group}/{profile}.")

    add = pkgs(f.get("add", ""), "Add packages")
    remove = pkgs(f.get("remove", ""), "Remove packages")
    if len(add) + len(remove) > MAX_PKGS:
        fail(f"At most {MAX_PKGS} added and removed packages.")
    script = f.get("script", "")
    if len(script.encode()) > MAX_SCRIPT:
        fail(f"The first-boot script is limited to {MAX_SCRIPT} bytes.")

    base = [p for p in entry["packages"] if p not in ("kernel", "libc") and p not in remove]
    # The ImageBuilder adds the profile's default packages to any list, also
    # those the release's config left out (dropbear, the mbedtls variants),
    # which it never built. Leave out every default the image does not carry.
    prof = fetch(f"{site}/{tag}/{group}/profiles.json")
    defaults = prof["default_packages"] + prof["profiles"][profile].get("device_packages", [])
    dropped = [p for p in defaults if not p.startswith("-") and p not in entry["packages"]
               and p not in remove]
    # custom.yml tags the snapshot feeds, so only added packages and their
    # dependencies may come from them, never a newer copy of the image's own.
    packages = " ".join(base + [f"{p}@snapshot" for p in add if p not in base]
                        + [f"-{p}" for p in remove + dropped])

    if script:
        with open(os.environ["UCI_DEFAULTS_OUT"], "w") as fh:
            fh.write(script.rstrip("\n") + "\n")

    title = entry["titles"][0] if entry["titles"] else profile
    with open(os.environ["GITHUB_OUTPUT"], "a") as fh:
        fh.write(f"tag={tag}\ngroup={group}\nprofile={profile}\n"
                 f"packages={packages}\ntitle={title}\n"
                 f"summary=+{len(add)} -{len(remove)} packages"
                 f"{', with a first-boot script' if script else ''}\n")
    print(f"{tag} {group}/{profile}: +{add} -{remove}")


if __name__ == "__main__":
    main()
