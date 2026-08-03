#!/usr/bin/env bash
set -euo pipefail

SETUP_LOG="${HOME}/setup.log"
: > "$SETUP_LOG"
exec > >(tee -a "$SETUP_LOG") 2>&1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ELIXIR_VERSION="${ELIXIR_VERSION:-1.18.4}"
INSTALLS_DIR="${HOME}/.elixir-install/installs"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mWARN:\033[0m %s\n' "$*"; }
error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }

trap 'status=$?; error "Setup failed at line ${LINENO}: ${BASH_COMMAND} (exit ${status})"; exit "${status}"' ERR

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    error "Root privileges are required to install system packages."
    exit 1
  fi
}

install_system_packages() {
  if ! command -v apt-get >/dev/null 2>&1; then
    error "apt-get is required to install the development dependencies."
    exit 1
  fi

  info "Installing system dependencies..."
  run_as_root env DEBIAN_FRONTEND=noninteractive apt-get update
  run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    erlang \
    git \
    openssl \
    postgresql \
    postgresql-client
}

elixir_compatible() {
  local installed_version major minor

  command -v elixir >/dev/null 2>&1 || return 1
  installed_version="$(elixir -e 'IO.write(System.version())')"
  major="${installed_version%%.*}"
  minor="${installed_version#*.}"
  minor="${minor%%.*}"

  (( major > 1 || (major == 1 && minor >= 15) ))
}

install_elixir() {
  local elixir_dir executable temp_dir

  if elixir_compatible && command -v mix >/dev/null 2>&1; then
    return
  fi

  info "Building Elixir ${ELIXIR_VERSION} against the system Erlang/OTP..."
  temp_dir="$(mktemp -d)"
  elixir_dir="${INSTALLS_DIR}/elixir/${ELIXIR_VERSION}"

  curl -fsSL \
    "https://github.com/elixir-lang/elixir/archive/refs/tags/v${ELIXIR_VERSION}.tar.gz" \
    --output "${temp_dir}/elixir.tar.gz"
  mkdir -p "$elixir_dir"
  tar -xzf "${temp_dir}/elixir.tar.gz" --strip-components=1 -C "$elixir_dir"
  make -C "$elixir_dir"
  rm -rf "$temp_dir"

  if [ ! -x "${elixir_dir}/bin/elixir" ]; then
    error "Elixir installation did not produce the expected binaries."
    exit 1
  fi

  export PATH="${elixir_dir}/bin:${PATH}"

  for executable in elixir elixirc iex mix; do
    run_as_root ln -sf "${elixir_dir}/bin/${executable}" "/usr/local/bin/${executable}"
  done
}

postgres_ready() {
  pg_isready -h localhost -p 5432 -q
}

install_postgres() {
  if ! postgres_ready; then
    info "Starting PostgreSQL..."
    run_as_root /usr/sbin/service postgresql start
  fi

  for _attempt in {1..30}; do
    postgres_ready && break
    sleep 1
  done

  if ! postgres_ready; then
    error "PostgreSQL did not become ready within 30 seconds."
    exit 1
  fi

  if ! PGPASSWORD=postgres psql -h localhost -U postgres -d postgres \
    --no-align --tuples-only --command "SELECT 1" >/dev/null 2>&1; then
    info "Configuring the PostgreSQL development user..."
    run_as_root /usr/sbin/runuser -u postgres -- \
      psql --set ON_ERROR_STOP=1 --command "ALTER USER postgres PASSWORD 'postgres';"
  fi

  info "PostgreSQL is ready on localhost:5432"
}

info "Checking prerequisites..."
install_system_packages

install_postgres
install_elixir

info "Elixir $(elixir -e 'IO.write(System.version())')"

info "Installing Hex and Rebar..."
mix local.hex --force
mix local.rebar --force

info "Installing Elixir dependencies..."
mix deps.get

info "Installing npm dependencies..."
npm ci --prefix assets

info "Setting up the development database and assets..."
mix setup

info "Verifying compilation..."
mix compile --warnings-as-errors

info "Building Dialyzer PLT..."
mix dialyzer --plt

printf '\n'
info "Setup complete. You can now:"
info "  mix phx.server      # Start the development server"
info "  iex -S mix phx.server # Start the server inside IEx"
info "  mix precommit       # Run project checks"
