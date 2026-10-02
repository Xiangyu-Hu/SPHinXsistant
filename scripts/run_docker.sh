#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${SPHINXSISTANT_IMAGE:-sphinxsistant:v1}"
CONTAINER_NAME="${SPHINXSISTANT_CONTAINER:-sphinxsistant}"
HOST_PORT="${SPHINXSISTANT_PORT:-7860}"
CONTAINER_PORT=7860

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

log() {
  printf '[SPHinXsistant] %s\n' "$*"
}

warn() {
  printf '[SPHinXsistant] WARNING: %s\n' "$*" >&2
}

fail() {
  printf '[SPHinXsistant] ERROR: %s\n' "$*" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 ||
  fail "Docker is not installed or not on PATH."

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1; then
  log "Docker requires sudo on this system; you may be asked for your password."
  sudo docker info >/dev/null 2>&1 ||
    fail "Docker daemon is unavailable."
  DOCKER=(sudo docker)
else
  fail "Docker daemon is unavailable for the current user."
fi

if [[ -z "${LLM_API_KEY:-}" ]]; then
  fail "LLM_API_KEY is not set. Export your API key before running this script."
fi

export LLM_MODEL="${LLM_MODEL:-nvidia/nemotron-3-ultra-550b-a55b}"
export LLM_BASE_URL="${LLM_BASE_URL:-https://integrate.api.nvidia.com/v1}"

mkdir -p "$PROJECT_ROOT/data/user_testing"

log "Project root: $PROJECT_ROOT"
log "LLM model: $LLM_MODEL"
log "LLM base URL: $LLM_BASE_URL"

log "Building Docker image: $IMAGE_NAME"
"${DOCKER[@]}" build -t "$IMAGE_NAME" "$PROJECT_ROOT"

RUN_ARGS=(
  --rm
  -it
  --name "$CONTAINER_NAME"
  --user "$(id -u):$(id -g)"

  -e GRADIO_SERVER_NAME=0.0.0.0

  -e "LLM_API_KEY=$LLM_API_KEY"
  -e "LLM_MODEL=$LLM_MODEL"
  -e "LLM_BASE_URL=$LLM_BASE_URL"

  -e GIT_TERMINAL_PROMPT=0

  -v "$PROJECT_ROOT/data/user_testing:/workspace/data/user_testing"

  -p "127.0.0.1:${HOST_PORT}:${CONTAINER_PORT}"
)

# Git repository bridge: mount the tester's Git metadata so Submission V1
# uses the tester's existing branch and remotes.
if [[ -d "$PROJECT_ROOT/.git" ]]; then
  RUN_ARGS+=(
    -v "$PROJECT_ROOT/.git:/workspace/.git"
  )

  GIT_NAME="$(git -C "$PROJECT_ROOT" config user.name 2>/dev/null || true)"
  GIT_EMAIL="$(git -C "$PROJECT_ROOT" config user.email 2>/dev/null || true)"

  if [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]]; then
    RUN_ARGS+=(
      -e "GIT_AUTHOR_NAME=$GIT_NAME"
      -e "GIT_AUTHOR_EMAIL=$GIT_EMAIL"
      -e "GIT_COMMITTER_NAME=$GIT_NAME"
      -e "GIT_COMMITTER_EMAIL=$GIT_EMAIL"
    )
  else
    warn "Git user.name/user.email are incomplete."
    warn "Submission commit may fail until Git identity is configured."
  fi
else
  warn "No .git directory found."
  warn "Gradio will run, but Git Submission will not be available."
fi

# GitHub SSH authentication bridge: forward the host ssh-agent socket without
# copying a private key. HTTPS GitHub remotes are rewritten to SSH only inside
# the container when the host has already trusted github.com.
SSH_FORWARDING=false

if [[ -n "${SSH_AUTH_SOCK:-}" \
      && -S "${SSH_AUTH_SOCK:-}" ]] \
      && ssh-add -l >/dev/null 2>&1; then

  KNOWN_HOSTS="$HOME/.ssh/known_hosts"

  if [[ -f "$KNOWN_HOSTS" ]] \
      && ssh-keygen -F github.com -f "$KNOWN_HOSTS" >/dev/null 2>&1; then

    RUN_ARGS+=(
      -e SSH_AUTH_SOCK=/ssh-agent

      -e GIT_CONFIG_COUNT=1
      -e 'GIT_CONFIG_KEY_0=url.git@github.com:.insteadOf'
      -e 'GIT_CONFIG_VALUE_0=https://github.com/'

      -e 'GIT_SSH_COMMAND=ssh -o UserKnownHostsFile=/tmp/known_hosts -o StrictHostKeyChecking=yes'

      -v "$SSH_AUTH_SOCK:/ssh-agent"
      -v "$KNOWN_HOSTS:/tmp/known_hosts:ro"
    )

    SSH_FORWARDING=true
  else
    warn "SSH agent found, but github.com is not trusted in ~/.ssh/known_hosts."
    warn "Git push via SSH is not enabled."
    warn "Run 'ssh -T git@github.com' once on the host, verify GitHub's fingerprint, then rerun this script."
  fi
else
  warn "No SSH key is available through an active ssh-agent."
  warn "Gradio and feedback logging will work, but authenticated Git push is not enabled."
fi

if [[ "$SSH_FORWARDING" == true ]]; then
  log "GitHub SSH-agent forwarding: enabled"
else
  log "GitHub SSH-agent forwarding: disabled"
fi

log "Starting SPHinXsistant."
log "Open in your browser: http://127.0.0.1:${HOST_PORT}"
log "Press Ctrl+C to stop the container."

exec "${DOCKER[@]}" run "${RUN_ARGS[@]}" "$IMAGE_NAME"
