#!/usr/bin/env bash
set -euo pipefail

START_LOG="${HOME}/start.log"
: > "$START_LOG"
exec > >(tee -a "$START_LOG") 2>&1

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    error "Root privileges are required to start PostgreSQL."
    exit 1
  fi
}

postgres_ready() {
  pg_isready -h localhost -p 5432 -q
}

if postgres_ready; then
  info "PostgreSQL is already running on localhost:5432"
  exit 0
fi

info "Starting PostgreSQL..."
run_as_root /usr/sbin/service postgresql start

for _attempt in {1..30}; do
  postgres_ready && break
  sleep 1
done

if ! postgres_ready; then
  error "PostgreSQL did not become ready within 30 seconds."
  exit 1
fi

info "PostgreSQL is ready on localhost:5432"
