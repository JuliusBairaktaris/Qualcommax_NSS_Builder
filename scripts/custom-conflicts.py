#!/usr/bin/env python3
"""Drop the image's variant of a package when a request brings another one.

ip-tiny and ip-full, tc-tiny and tc-full, the wpad builds: the release image
carries one variant, and a request that adds another, or adds a package that
depends on another (pbr on ip-full), cannot be installed beside it. apk names
both in its "unable to select packages" report. A variant that only the image
asks for, and that conflicts with one the request brings, is taken out.

    custom-conflicts.py <build log> <package list>

prints the package list with those variants removed (and listed as -name for
the ImageBuilder), then a line with their names. It prints nothing when the
report holds no such pair, so every other failure stays a failure.
"""
import re
import sys

VERSIONED = re.compile(r"^(.+?)-\d[^-]*-r\d+$")


def name(token):
    m = VERSIONED.match(token)
    return m.group(1) if m else token


def blocks(log):
    """apk's report as {package: (packages it conflicts with, world entries)}."""
    out, cur, field = {}, None, None
    on = False
    for line in log.splitlines():
        if line.startswith("ERROR: unable to select packages"):
            on = True
            continue
        if not on:
            continue
        if not line.startswith("  "):
            break
        m = re.match(r"^  (\S+):$", line)
        if m:
            cur = out.setdefault(name(m.group(1)), (set(), set()))
            field = None
            continue
        if cur is None:
            continue
        m = re.match(r"^\s+(conflicts|satisfies|required by|provided by|note):(.*)$", line)
        text = line
        if m:
            field, text = m.group(1), m.group(2)
        for token in text.split():
            owner = token.split("[", 1)[0]
            if field == "conflicts":
                cur[0].add(name(owner))
            elif field == "satisfies" and owner == "world":
                cur[1].add(token[len("world["):].rstrip("]"))
    return out


def replaced(log):
    rep = blocks(log)
    # The image's own packages are in the world untagged; the request's carry
    # the tag of the snapshot feeds, and a dependency is in no world entry.
    own = {p for p, (_, world) in rep.items() if p in world}
    return sorted(p for p in own if any(c in rep and c not in own for c in rep[p][0]))


def main():
    log = open(sys.argv[1], errors="replace").read()
    drop = replaced(log)
    packages = sys.argv[2].split()
    drop = [p for p in drop if p in packages]
    if not drop:
        return
    print(" ".join([p for p in packages if p not in drop] + [f"-{p}" for p in drop]))
    print(" ".join(drop))


if __name__ == "__main__":
    main()
