#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-${HOME:-/root}/claudgaming-moonlight}"
MOONLIGHT_RELEASE_URL="https://github.com/kmille36/moonlight-web-remote/releases/download/0.0.2/colab-linux.zip"
CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"

info() { echo -e "\e[1;34m[INFO]\e[0m $*"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

check_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    error "Этот скрипт должен запускаться от root или через sudo."
  fi
}

check_colab() {
  if [ -d /content ]; then
    INSTALL_DIR="${INSTALL_DIR:-/content/claudgaming-moonlight}"
  fi
}

check_gpu() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)"
  else
    echo "GPU: не найден nvidia-smi. Убедитесь, что в Colab включена Tesla T4."
  fi
}

install_dependencies() {
  info "Устанавливаю зависимости..."
  apt-get update
  apt-get install -y software-properties-common curl wget unzip ca-certificates gnupg2 lsb-release xauth xvfb procps
  dpkg --add-architecture i386 || true
  apt-get update
  apt-get install -y libgl1-mesa-dri libgl1-mesa-glx libglapi-mesa libglu1-mesa libx11-6 libxrandr2 libxinerama1 libxcursor1 libxss1 libxcb1 libxext6 libxi6 libice6 libsm6 libfontconfig1 libfreetype6 libdbus-1-3 libnss3 libasound2 libsdl2-2.0-0 libcurl4 libcurl4-openssl-dev
  apt-get install -y steamcmd || info "SteamCMD не найден в apt, установлю steamcmd вручную"
  apt-get install -y cloudflared || info "cloudflared не найден в apt, установлю вручную"
}

install_steamcmd() {
  if command -v steamcmd >/dev/null 2>&1; then
    return
  fi

  info "Устанавливаю steamcmd вручную..."
  mkdir -p /opt/steamcmd
  curl -L -o /tmp/steamcmd_linux.tar.gz "$STEAMCMD_URL"
  tar -xzf /tmp/steamcmd_linux.tar.gz -C /opt/steamcmd
  ln -sf /opt/steamcmd/steamcmd.sh /usr/local/bin/steamcmd
}

install_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then
    return
  fi
  info "Устанавливаю cloudflared..."
  curl -L -o /usr/local/bin/cloudflared "$CLOUDFLARED_URL"
  chmod +x /usr/local/bin/cloudflared
}

ensure_cloudflared() {
  if ! command -v cloudflared >/dev/null 2>&1; then
    install_cloudflared
  fi
}

install_moonlight_web() {
  info "Скачиваю moonlight-web-remote..."
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  rm -f /tmp/moonlight-web.zip
  curl -L -o /tmp/moonlight-web.zip "$MOONLIGHT_RELEASE_URL"
  rm -rf /tmp/moonlight-web-contents
  mkdir -p /tmp/moonlight-web-contents
  unzip -o /tmp/moonlight-web.zip -d /tmp/moonlight-web-contents
  if [ -f /tmp/moonlight-web-contents/package/streamer ] && [ -f /tmp/moonlight-web-contents/package/web-server ]; then
    mv /tmp/moonlight-web-contents/package/streamer "$INSTALL_DIR"/streamer
    mv /tmp/moonlight-web-contents/package/web-server "$INSTALL_DIR"/web-server
  else
    mv /tmp/moonlight-web-contents/streamer "$INSTALL_DIR"/streamer 2>/dev/null || true
    mv /tmp/moonlight-web-contents/web-server "$INSTALL_DIR"/web-server 2>/dev/null || true
  fi
  chmod +x "$INSTALL_DIR"/streamer "$INSTALL_DIR"/web-server || true
  mkdir -p "$INSTALL_DIR/server"
  rm -rf /tmp/moonlight-web-contents
}

write_config() {
  local cfg="$INSTALL_DIR/server/config.json"
  info "Записываю конфигурацию Moonlight Web в $cfg"
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
}

show_summary() {
  local ip local_ip pub_ip
  local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
  pub_ip=$(curl -s ifconfig.me || true)
  info "Готово!"
  echo
  echo "Moonlight Web URL: http://$local_ip:8080"
  echo "Moonlight stream порт: 47989"
  [ -n "$pub_ip" ] && echo "Публичный IP: $pub_ip"
  echo "Файлы установлены в: $INSTALL_DIR"
  echo "Для запуска используйте: sudo bash clab_claud_gaming.sh run"
  check_gpu
}

run_server() {
  local pin
  read -r -p "Введите PIN для подключения Moonlight (4 цифры, например 1234): " pin
  if ! [[ $pin =~ ^[0-9]{4}$ ]]; then
    error "PIN должен быть ровно 4 цифры."
  fi
  mkdir -p "$INSTALL_DIR/server"
  echo "$pin" > "$INSTALL_DIR/server/pair-pin.txt"

  info "Запускаю Moonlight Web server..."
  cd "$INSTALL_DIR"
  nohup ./web-server --config-path server/config.json > "$INSTALL_DIR/web-server.log" 2>&1 &
  local web_pid=$!
  info "web-server запущен PID $web_pid"

  sleep 4
  info "Пытаюсь запустить Cloudflare tunnel..."
  ensure_cloudflared
  nohup cloudflared tunnel --url http://127.0.0.1:8080 --no-autoupdate --logfile "$INSTALL_DIR/cloudflared.log" --loglevel info > /dev/null 2>&1 &
  sleep 6
  local tunnel_url=""
  for i in 1 2 3 4 5 6; do
    tunnel_url=$(grep -oE 'https?://[^ ]+trycloudflare\.com' "$INSTALL_DIR/cloudflared.log" | tail -n 1 || true)
    if [ -n "$tunnel_url" ]; then
      break
    fi
    sleep 2
  done
  if [ -n "$tunnel_url" ]; then
    echo "Cloudflare tunnel URL: $tunnel_url"
  else
    info "Cloudflare tunnel запущен, но публичный URL ещё не получен. Проверьте лог: $INSTALL_DIR/cloudflared.log"
  fi

  local local_ip
  local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
  info "Moonlight Web должен быть доступен по локальному адресу:"
  echo "  http://127.0.0.1:8080"
  echo "  локальный адрес: http://$local_ip:8080"
  echo "PIN для подключения Moonlight: $pin"
  echo "Порт Moonlight по умолчанию: 47989"
  echo "Если вы используете Google Colab, публичный доступ возможен только через Cloudflare tunnel."
  echo "Чтобы запустить Steam через Xvfb используйте:"
  echo "  xvfb-run -s '-screen 0 1920x1080x24' steam"
  echo "Или запустите SteamCMD для установки/ обновления игр:"
  echo "  steamcmd +login anonymous"
}

start_steam() {
  if ! command -v steam >/dev/null 2>&1; then
    error "Steam клиент не найден. Установите Steam или используйте steamcmd."
  fi

  info "Запускаю Steam в виртуальном дисплее..."
  nohup xvfb-run -s "-screen 0 1920x1080x24" steam > "$INSTALL_DIR/steam.log" 2>&1 &
  echo "Steam запущен в фоне, лог: $INSTALL_DIR/steam.log"
}

start_steamcmd() {
  if ! command -v steamcmd >/dev/null 2>&1; then
    error "steamcmd не найден. Установите его через install."
  fi
  info "Запускаю steamcmd..."
  nohup steamcmd +login anonymous > "$INSTALL_DIR/steamcmd.log" 2>&1 &
  echo "steamcmd запущен в фоне, лог: $INSTALL_DIR/steamcmd.log"
}

print_usage() {
  cat <<'EOF'
Использование:
  sudo bash clab_claud_gaming.sh install      # установить Moonlight Web, SteamCMD и cloudflared
  sudo bash clab_claud_gaming.sh run          # запустить Moonlight Web и Cloudflare туннель
  sudo bash clab_claud_gaming.sh steam        # запустить Steam через Xvfb (если установлен)
  sudo bash clab_claud_gaming.sh steamcmd     # запустить steamcmd для установки игр
  sudo bash clab_claud_gaming.sh help         # показать эту помощь

После установки Steam/SteamCMD запустите клиент, затем подключитесь через Moonlight.
EOF
}

main() {
  check_root
  check_colab
  case "${1:-}" in
    install)
      install_dependencies
      install_steamcmd
      install_cloudflared
      install_moonlight_web
      write_config
      show_summary
      ;;
    run)
      run_server
      ;;
    steam)
      start_steam
      ;;
    steamcmd)
      start_steamcmd
      ;;
    help|--help|-h|"")
      print_usage
      ;;
    *)
      print_usage
      exit 1
      ;;
  esac
}

main "$@"
