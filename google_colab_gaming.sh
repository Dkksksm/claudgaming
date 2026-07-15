#!/usr/bin/env bash
#
# Google Colab Cloud Gaming Setup Script
# Автоматическая установка облачного гейминга в Google Colab с Tesla T4
#
# Использование:
#   sudo bash google_colab_gaming.sh
#
# Опциональные переменные окружения:
#   PIN=1234 sudo bash google_colab_gaming.sh          # Установить PIN предварительно
#   INSTALL_DIR=/custom/path sudo bash google_colab_gaming.sh  # Пользовательская папка

set -euo pipefail

# ============================================================================
# КОНФИГУРАЦИЯ
# ============================================================================

INSTALL_DIR="${INSTALL_DIR:-/content/claudgaming-moonlight}"
MOONLIGHT_RELEASE_URL="https://github.com/kmille36/moonlight-web-remote/releases/download/0.0.2/colab-linux.zip"
CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
PIN="${PIN:-1234}"
MOONLIGHT_PORT="8080"
STREAMING_PORT="47989"

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================================================

info() { 
  printf '\e[1;34m[ℹ INFO]\e[0m %s\n' "$*"
}

success() { 
  printf '\e[1;32m[✓ OK]\e[0m %s\n' "$*"
}

error() { 
  printf '\e[1;31m[✗ ERROR]\e[0m %s\n' "$*" >&2
  exit 1
}

warn() { 
  printf '\e[1;33m[⚠ WARNING]\e[0m %s\n' "$*"
}

# ============================================================================
# ПРОВЕРКИ
# ============================================================================

check_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    error "Этот скрипт должен запускаться от root. Используйте: sudo bash $0"
  fi
}

check_colab() {
  if [ -d /content ]; then
    info "✓ Обнаружена Google Colab среда"
    INSTALL_DIR="/content/claudgaming-moonlight"
    return 0
  else
    warn "Google Colab не обнаружена. Используется локальная установка."
    return 1
  fi
}

check_gpu() {
  info "Проверяю GPU..."
  if command -v nvidia-smi >/dev/null 2>&1; then
    local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1)
    local gpu_memory=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -n 1)
    success "GPU обнаружена: $gpu_name ($gpu_memory)"
  else
    warn "nvidia-smi не найден. GPU может быть недоступна."
  fi
}

check_internet() {
  info "Проверяю интернет-соединение..."
  if ! curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1; then
    error "Нет соединения с интернетом. Проверьте подключение."
  fi
  success "Интернет доступен"
}

# ============================================================================
# УСТАНОВКА ЗАВИСИМОСТЕЙ
# ============================================================================

install_dependencies() {
  info "Устанавливаю системные зависимости (это может занять 2-3 минуты)..."
  
  # Обновляю пакеты
  apt-get update -qq || true
  
  # Базовые инструменты
  apt-get install -y -qq \
    curl wget unzip ca-certificates gnupg2 \
    software-properties-common lsb-release \
    xauth xvfb procps mesa-utils \
    --no-install-recommends || true
  
  # Графические библиотеки
  dpkg --add-architecture i386 || true
  apt-get update -qq || true
  
  apt-get install -y -qq \
    libgl1-mesa-dri libgl1-mesa-glx libglapi-mesa libglu1-mesa \
    libx11-6 libxrandr2 libxinerama1 libxcursor1 libxss1 \
    libxcb1 libxext6 libxi6 libice6 libsm6 \
    libfontconfig1 libfreetype6 libdbus-1-3 \
    libnss3 libasound2 libsdl2-2.0-0 libcurl4 \
    libcurl4-openssl-dev \
    --no-install-recommends || true
  
  # Пытаюсь установить через apt
  apt-get install -y -qq steamcmd cloudflared --no-install-recommends 2>/dev/null || true
  
  success "Зависимости установлены"
}

install_steamcmd() {
  if command -v steamcmd >/dev/null 2>&1; then
    success "steamcmd уже установлен"
    return
  fi
  
  info "Устанавливаю steamcmd вручную..."
  mkdir -p /opt/steamcmd
  
  local temp_dir
  temp_dir=$(mktemp -d)
  curl -L -s -o "$temp_dir/steamcmd.tar.gz" "$STEAMCMD_URL" || error "Не удалось скачать steamcmd"
  tar -xzf "$temp_dir/steamcmd.tar.gz" -C /opt/steamcmd
  ln -sf /opt/steamcmd/steamcmd.sh /usr/local/bin/steamcmd
  chmod +x /opt/steamcmd/steamcmd.sh
  rm -rf "$temp_dir"
  
  success "steamcmd установлен"
}

install_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then
    success "cloudflared уже установлен"
    return
  fi
  
  info "Устанавливаю cloudflared..."
  curl -L -s -o /usr/local/bin/cloudflared "$CLOUDFLARED_URL" || error "Не удалось скачать cloudflared"
  chmod +x /usr/local/bin/cloudflared
  
  success "cloudflared установлен"
}

install_moonlight_web() {
  info "Скачиваю и устанавливаю Moonlight Web..."
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  
  local temp_zip
  temp_zip=$(mktemp --suffix=.zip)
  curl -L -s -o "$temp_zip" "$MOONLIGHT_RELEASE_URL" || error "Не удалось скачать Moonlight Web"
  
  local temp_dir
  temp_dir=$(mktemp -d)
  unzip -q -o "$temp_zip" -d "$temp_dir" || error "Не удалось распаковать Moonlight Web"
  
  # Проверяю структуру распакованных файлов
  if [ -d "$temp_dir/package" ]; then
    if [ -f "$temp_dir/package/streamer" ] && [ -f "$temp_dir/package/web-server" ]; then
      mv "$temp_dir/package/streamer" "$INSTALL_DIR/streamer"
      mv "$temp_dir/package/web-server" "$INSTALL_DIR/web-server"
    fi
  else
    if [ -f "$temp_dir/streamer" ] && [ -f "$temp_dir/web-server" ]; then
      mv "$temp_dir/streamer" "$INSTALL_DIR/streamer"
      mv "$temp_dir/web-server" "$INSTALL_DIR/web-server"
    fi
  fi
  
  chmod +x "$INSTALL_DIR/web-server" "$INSTALL_DIR/streamer" 2>/dev/null || true
  mkdir -p "$INSTALL_DIR/server"
  
  rm -f "$temp_zip"
  rm -rf "$temp_dir"
  
  if [ ! -f "$INSTALL_DIR/web-server" ]; then
    error "Не удалось установить Moonlight Web. Проверьте архив."
  fi
  
  success "Moonlight Web установлен в $INSTALL_DIR"
}

# ============================================================================
# КОНФИГУРАЦИЯ
# ============================================================================

write_config() {
  local cfg="$INSTALL_DIR/server/config.json"
  
  info "Записываю конфигурацию Moonlight Web..."
  
  cat > "$cfg" <<'EOF'
{
  "data_storage": {
    "type": "json",
    "path": "server/data.json",
    "session_expiration_check_interval": {"secs": 300, "nanos": 0}
  },
  "webrtc": {
    "ice_servers": [
      {
        "urls": [
          "stun:stun.l.google.com:19302",
          "stun:stun.l.google.com:5349",
          "stun:stun1.l.google.com:3478",
          "stun:stun1.l.google.com:5349",
          "stun:stun2.l.google.com:19302",
          "stun:stun2.l.google.com:5349",
          "stun:stun3.l.google.com:3478",
          "stun:stun3.l.google.com:5349",
          "stun:stun4.l.google.com:19302",
          "stun:stun4.l.google.com:5349"
        ],
        "username": "",
        "credential": ""
      }
    ],
    "ice_server_script": null,
    "port_range": "10000:20000",
    "nat_1to1": null,
    "network_types": ["udp4", "udp6"],
    "include_loopback_candidates": true
  },
  "web_server": {
    "bind_address": "0.0.0.0:8080",
    "certificate": null,
    "url_path_prefix": "",
    "session_cookie_secure": false,
    "session_cookie_expiration": {"secs": 86400, "nanos": 0},
    "first_login_create_admin": true,
    "first_login_assign_global_hosts": true,
    "default_user_id": null,
    "default_role_id": null,
    "forwarded_header": null
  },
  "moonlight": {
    "default_http_port": 47989,
    "pair_device_name": "claudgaming"
  },
  "streamer_path": "./streamer",
  "log": {
    "level_filter": "INFO",
    "file_path": null,
    "dev_venator": false
  },
  "default_settings": null
}
EOF

  success "Конфигурация записана"
}

# ============================================================================
# ЗАПУСК СЕРВИСОВ
# ============================================================================

start_moonlight_web() {
  info "Запускаю Moonlight Web server..."
  
  # Проверяю PIN
  if ! [[ $PIN =~ ^[0-9]{4}$ ]]; then
    error "PIN должен быть ровно 4 цифры (например, 1234)"
  fi
  
  # Записываю PIN
  echo "$PIN" > "$INSTALL_DIR/server/pair-pin.txt"
  
  # Запускаю web-server
  cd "$INSTALL_DIR" || error "Не удалось перейти в $INSTALL_DIR"
  
  nohup stdbuf -oL -eL ./web-server --config-path server/config.json \
    > "$INSTALL_DIR/web-server.log" 2>&1 &
  local web_pid=$!
  
  success "Moonlight Web запущен (PID: $web_pid)"
  sleep 3
}

start_cloudflare_tunnel() {
  info "Запускаю Cloudflare tunnel..."
  
  if ! command -v cloudflared >/dev/null 2>&1; then
    error "cloudflared не установлен"
  fi
  
  nohup stdbuf -oL -eL cloudflared tunnel --url http://127.0.0.1:$MOONLIGHT_PORT \
    --no-autoupdate --loglevel info \
    > "$INSTALL_DIR/cloudflared.log" 2>&1 &
  local cf_pid=$!
  
  success "Cloudflare tunnel запущен (PID: $cf_pid)"
  sleep 8
}

# ============================================================================
# ВЫВОД ИНФОРМАЦИИ
# ============================================================================

get_tunnel_url() {
  local url=""
  local attempts=0
  
  while [ $attempts -lt 10 ]; do
    if [ -f "$INSTALL_DIR/cloudflared.log" ]; then
      url=$(grep -oE 'https?://[^ ]+trycloudflare\.com' "$INSTALL_DIR/cloudflared.log" | tail -n 1 || true)
      if [ -n "$url" ]; then
        echo "$url"
        return 0
      fi
    fi
    attempts=$((attempts + 1))
    sleep 1
  done
  
  return 1
}

print_connection_info() {
  echo
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║           ОБЛАЧНЫЙ ГЕЙМИНГ В GOOGLE COLAB ГОТОВ К РАБОТЕ            ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo
  echo "📍 ИНФОРМАЦИЯ О ПОДКЛЮЧЕНИИ:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  echo "  🔐 PIN для подключения Moonlight:    $PIN"
  echo "  🌐 Локальный адрес:                  http://127.0.0.1:$MOONLIGHT_PORT"
  echo "  📡 Порт стриминга Moonlight:         $STREAMING_PORT"
  echo "  📁 Папка установки:                  $INSTALL_DIR"
  echo
  
  local tunnel_url
  tunnel_url=$(get_tunnel_url)
  if [ -n "$tunnel_url" ]; then
    echo "  🚀 ПУБЛИЧНЫЙ URL (Cloudflare):       $tunnel_url"
    echo "     ☝️ ИСПОЛЬЗУЙТЕ ЭТОТ URL для подключения из интернета!"
  else
    echo "  ⏳ Публичный URL еще не готов..."
    echo "     Проверьте лог: $INSTALL_DIR/cloudflared.log"
  fi
  echo
  echo "📋 ЛОГИ:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Moonlight Web:  $INSTALL_DIR/web-server.log"
  echo "  Cloudflare:     $INSTALL_DIR/cloudflared.log"
  echo
  echo "📝 СЛЕДУЮЩИЕ ШАГИ:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  echo "  1. Откройте публичный URL в браузере (если он уже готов)"
  echo "  2. Установите Steam через 'steamcmd' команду"
  echo "  3. Подключитесь через Moonlight клиент"
  echo "  4. Запустите игры!"
  echo
  echo "💡 ДОПОЛНИТЕЛЬНЫЕ КОМАНДЫ:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  # Запустить Steam в виртуальном дисплее"
  echo "  nohup xvfb-run -s '-screen 0 1920x1080x24' steam > steam.log 2>&1 &"
  echo
  echo "  # Запустить steamcmd для установки игр"
  echo "  steamcmd +login anonymous"
  echo
  echo "  # Проверить логи в реальном времени"
  echo "  tail -f $INSTALL_DIR/web-server.log"
  echo
  echo "════════════════════════════════════════════════════════════════════════"
  echo
}

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================

main() {
  info "🎮 Google Colab Cloud Gaming Setup"
  echo
  
  check_root
  check_internet
  check_colab
  check_gpu
  echo
  
  # Установка
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "ЭТАП 1: Установка зависимостей"
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  install_dependencies
  echo
  
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "ЭТАП 2: Установка компонентов"
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  install_steamcmd
  install_cloudflared
  install_moonlight_web
  echo
  
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "ЭТАП 3: Конфигурация"
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  write_config
  echo
  
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "ЭТАП 4: Запуск сервисов"
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  start_moonlight_web
  start_cloudflare_tunnel
  echo
  
  # Выводу информацию
  print_connection_info
  
  # Держу ячейку активной
  info "Ячейка остается активной. Нажмите Ctrl+C, чтобы остановить."
  echo
  tail -f -n 0 "$INSTALL_DIR/web-server.log" "$INSTALL_DIR/cloudflared.log" 2>/dev/null &
  tail_pid=$!
  
  # Обработка сигналов
  trap "kill $tail_pid 2>/dev/null; info 'Завершение работы'; exit 0" SIGINT SIGTERM
  
  wait $tail_pid 2>/dev/null || true
}

# ============================================================================
# ЗАПУСК
# ============================================================================

main "$@"
