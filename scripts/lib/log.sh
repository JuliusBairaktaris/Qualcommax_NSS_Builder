# shellcheck shell=bash
# Tiny logging helpers. Source this from other scripts.

log::info() { printf '[INFO]  %s\n' "$*"; }
log::warn() { printf '[WARN]  %s\n' "$*" >&2; }
log::error() { printf '[ERROR] %s\n' "$*" >&2; }
log::die() { log::error "$*"; exit 1; }
