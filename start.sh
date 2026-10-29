#!/usr/bin/env bash
# VoiceStudio local launcher. Run from any directory; Ctrl+C stops this session.
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export PATH="$HOME/.bun/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$PROJECT_DIR"

for dependency in bun uv node curl; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'Dependência não encontrada: %s\n' "$dependency" >&2
    exit 1
  fi
done

if [[ ! -x .venv/bin/python || ! -x node_modules/.bin/concurrently ]]; then
  printf 'Prepare o projeto primeiro: bun install && bun run setup:api\n' >&2
  exit 1
fi

PORTS="$(node - <<'JS'
const { ports } = require('./config/app.json');
const api = Number(process.env.OMNIVOICE_PORT || ports.backend);
const web = Number(process.env.OMNIVOICE_UI_PORT || process.env.VOICESTUDIO_UI_PORT || ports.web);
if (![api, web].every(port => Number.isInteger(port) && port > 0 && port < 65536) || api === web) {
  console.error('As portas do backend e frontend precisam ser válidas e diferentes.');
  process.exit(1);
}
console.log(api, web);
JS
)"
read -r API_PORT WEB_PORT <<< "$PORTS"
API_URL="http://127.0.0.1:$API_PORT"
WEB_URL="http://localhost:$WEB_PORT"
FRONTEND_URL="$WEB_URL/#/clone"

ready() {
  local html
  curl --noproxy '*' --fail --silent --max-time 2 "$API_URL/health" >/dev/null 2>&1 || return 1
  curl --noproxy '*' --fail --silent --max-time 2 "$WEB_URL/api/health" >/dev/null 2>&1 || return 1
  html="$(curl --noproxy '*' --fail --silent --max-time 2 "$WEB_URL/" 2>/dev/null)" || return 1
  [[ "$html" == *VoiceStudio* ]]
}

open_frontend() {
  printf '\nVoiceStudio pronto: %s\n' "$FRONTEND_URL"
  case "$(uname -s)" in
    Darwin) open "$FRONTEND_URL" ;;
    Linux) xdg-open "$FRONTEND_URL" ;;
    MINGW*|MSYS*|CYGWIN*) cmd.exe /c start '' "$FRONTEND_URL" ;;
    *) return 1 ;;
  esac
}

if ready; then
  open_frontend || printf 'Abra o endereço acima no navegador.\n' >&2
  exit 0
fi

if command -v lsof >/dev/null 2>&1; then
  for port in "$API_PORT" "$WEB_PORT"; do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
      printf 'A porta %s está ocupada e o VoiceStudio ainda não está pronto. Aguarde ou encerre o serviço antes de tentar novamente.\n' "$port" >&2
      exit 1
    fi
  done
fi

# Give this stack its own process group, so cleanup only stops our processes.
set -m
STACK_PID=''
cleanup() {
  local status=$?
  trap - EXIT INT TERM HUP
  if [[ -n "$STACK_PID" ]]; then
    kill -TERM -- "-$STACK_PID" 2>/dev/null || true
    for ((attempt = 0; attempt < 20; attempt++)); do
      kill -0 -- "-$STACK_PID" 2>/dev/null || break
      sleep 1
    done
    kill -KILL -- "-$STACK_PID" 2>/dev/null || true
    wait "$STACK_PID" 2>/dev/null || true
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

printf 'Iniciando o VoiceStudio…\n'
./node_modules/.bin/concurrently --kill-others -n api,frontend -c green,cyan \
  'bun run dev:api' 'bun run dev:frontend' &
STACK_PID=$!

STARTED_AT=$SECONDS
while ((SECONDS - STARTED_AT < 600)); do
  if ! kill -0 "$STACK_PID" 2>/dev/null; then
    printf 'O VoiceStudio encerrou antes de ficar pronto. Confira as mensagens acima.\n' >&2
    exit 1
  fi
  if ready; then
    open_frontend || printf 'Abra o endereço acima no navegador.\n' >&2
    printf 'Mantenha este terminal aberto. Pressione Ctrl+C para encerrar.\n'
    wait "$STACK_PID"
    exit 0
  fi
  sleep 1
done

printf 'O VoiceStudio não ficou pronto em 10 minutos. Confira as mensagens acima.\n' >&2
exit 1
