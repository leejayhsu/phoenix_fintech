#!/usr/bin/env bash
set -euo pipefail

# Codex Cloud setup script for the Ubuntu-based universal image.
# Installs Elixir/OTP into $HOME, then fetches and compiles this Phoenix app's deps.

ELIXIR_VERSION="${ELIXIR_VERSION:-1.20.1}"
OTP_VERSION="${OTP_VERSION:-28.4}"
INSTALLS_DIR="${HOME}/.elixir-install/installs"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELIXIR_INSTALL_TMP_DIR=""

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "This script needs root privileges to install Ubuntu packages." >&2
    exit 1
  fi
}

install_ubuntu_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    run_as_root apt-get update
    run_as_root apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      openssl \
      build-essential
    run_as_root update-ca-certificates
  fi
}

configure_mix_and_ssl_env() {
  export MIX_HOME="${HOME}/.mix"
  export HEX_HOME="${HOME}/.hex"
  export MIX_ARCHIVES="${MIX_HOME}/archives"
  export HEX_CACERTS_PATH="/etc/ssl/certs/ca-certificates.crt"
  export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

  mkdir -p "${MIX_HOME}" "${HEX_HOME}" "${MIX_ARCHIVES}"
}

elixir_bin_dir() {
  local otp_major="${OTP_VERSION%%.*}"
  local expected="${INSTALLS_DIR}/elixir/${ELIXIR_VERSION}-otp-${otp_major}/bin"

  if [ -d "${expected}" ]; then
    printf '%s\n' "${expected}"
    return 0
  fi

  local matches=("${INSTALLS_DIR}/elixir/${ELIXIR_VERSION}-otp-"*/bin)
  if [ -d "${matches[0]}" ]; then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  return 1
}

otp_bin_dir() {
  local expected="${INSTALLS_DIR}/otp/${OTP_VERSION}/bin"

  if [ -d "${expected}" ]; then
    printf '%s\n' "${expected}"
    return 0
  fi

  return 1
}

install_elixir() {
  local otp_bin=""
  local elixir_bin=""

  if otp_bin="$(otp_bin_dir 2>/dev/null)" && elixir_bin="$(elixir_bin_dir 2>/dev/null)"; then
    export PATH="${otp_bin}:${elixir_bin}:${PATH}"
    return 0
  fi

  ELIXIR_INSTALL_TMP_DIR="$(mktemp -d)"
  trap '[ -n "${ELIXIR_INSTALL_TMP_DIR}" ] && rm -rf "${ELIXIR_INSTALL_TMP_DIR}"' EXIT

  curl -fsSL "https://elixir-lang.org/install.sh" -o "${ELIXIR_INSTALL_TMP_DIR}/install.sh"
  sh "${ELIXIR_INSTALL_TMP_DIR}/install.sh" "elixir@${ELIXIR_VERSION}" "otp@${OTP_VERSION}"

  rm -rf "${ELIXIR_INSTALL_TMP_DIR}"
  ELIXIR_INSTALL_TMP_DIR=""
  trap - EXIT

  otp_bin="$(otp_bin_dir)"
  elixir_bin="$(elixir_bin_dir)"
  export PATH="${otp_bin}:${elixir_bin}:${PATH}"
}

persist_elixir_path() {
  local otp_bin elixir_bin marker_start marker_end
  otp_bin="$(otp_bin_dir)"
  elixir_bin="$(elixir_bin_dir)"
  marker_start="# >>> phoenix_fintech codex elixir v2 >>>"
  marker_end="# <<< phoenix_fintech codex elixir v2 <<<"

  for profile in "${HOME}/.profile" "${HOME}/.bashrc"; do
    touch "${profile}"
    if ! grep -Fq "${marker_start}" "${profile}"; then
      {
        printf '\n%s\n' "${marker_start}"
        printf 'export PATH="%s:%s:$PATH"\n' "${otp_bin}" "${elixir_bin}"
        printf 'export MIX_HOME="$HOME/.mix"\n'
        printf 'export HEX_HOME="$HOME/.hex"\n'
        printf 'export MIX_ARCHIVES="$MIX_HOME/archives"\n'
        printf 'export HEX_CACERTS_PATH="/etc/ssl/certs/ca-certificates.crt"\n'
        printf 'export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"\n'
        printf '%s\n' "${marker_end}"
      } >>"${profile}"
    fi
  done
}

link_elixir_bins() {
  local otp_bin elixir_bin exe source_path
  otp_bin="$(otp_bin_dir)"
  elixir_bin="$(elixir_bin_dir)"

  for exe in erl erlc epmd escript dialyzer elixir elixirc iex mix; do
    if [ -x "${elixir_bin}/${exe}" ]; then
      source_path="${elixir_bin}/${exe}"
    elif [ -x "${otp_bin}/${exe}" ]; then
      source_path="${otp_bin}/${exe}"
    else
      continue
    fi

    run_as_root ln -sf "${source_path}" "/usr/local/bin/${exe}"
  done
}

install_project_deps() {
  cd "${REPO_DIR}"

  mix local.hex --force
  mix local.rebar --force
  mix deps.get
  mix assets.setup
  mix deps.compile
}

install_ubuntu_packages
install_elixir
configure_mix_and_ssl_env
persist_elixir_path
link_elixir_bins

elixir --version
mix --version

install_project_deps

echo "Codex setup complete. Future shells may need: source ~/.bashrc"
