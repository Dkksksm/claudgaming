#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/content/claudgaming-moonlight}"
MOONLIGHT_RELEASE_URL="https://github.com/kmille36/moonlight-web-remote/releases/download/0.0.2/colab-linux.zip"
CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
PIN="${PIN:-}"

info() { printf '\e[1;34m[INFO]\e[0m %s\n' "$*"; }
error() { printf '\e[1;31m[ERROR]\e[0m %s\n' "$*" >&2; exit 1; }

check_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    error "Запустите скрипт от root: sudo bash $0"
  fi
}

install_dependencies() {
  info "Устанавливаю зависимости..."
  apt-get update
  apt-get install -y software-properties-common curl wget unzip ca-certificates gnupg2 lsb-release xauth xvfb procps
  dpkg --add-architecture i386 || true
  apt-get update
  apt-get install -y libgl1-mesa-dri libgl1-mesa-glx libglapi-mesa libglu1-mesa libx11-6 libxrandr2 libxinerama1 libxcursor1 libxss1 libxcb1 libxext6 libxi6 libice6 libsm6 libfontconfig1 libfreetype6 libdbus-1-3 libnss3 libasound2 libsdl2-2.0-0 libcurl4 libcurl4-openssl-dev
  apt-get install -y steamcmd || info "SteamCMD не найден в apt, установлю вручную"
  apt-get install -y cloudflared || info "cloudflared не найден в apt, установлю вручную"
}

install_steamcmd() {
  if command -v steamcmd >/dev/null 2>&1; then
    return
  fi
  info "Устанавливаю SteamCMD вручную..."
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

install_moonlight_web() {
  info "Скачиваю moonlight-web-remote..."
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  rm -f /tmp/moonlight-web.zip
  curl -L -o /tmp/moonlight-web.zip "$MOONLIGHT_RELEASE_URL"
  rm -rf /tmp/moonlight-web-contents
  mkdir -p /tmp/moonlight-web-contents
  unzip -o /tmp/moonlight-web.zip -d /tmp/moonlight-web-contents
  if [ -f /tmp/moonlight-web-contents/package/web-server ] && [ -f /tmp/moonlight-web-contents/package/streamer ]; then
    mv /tmp/moonlight-web-contents/package/web-server "$INSTALL_DIR/web-server"
    mv /tmp/moonlight-web-contents/package/streamer "$INSTALL_DIR/streamer"
  else
    mv /tmp/moonlight-web-contents/web-server "$INSTALL_DIR/web-server" 2>/dev/null || true
    mv /tmp/moonlight-web-contents/streamer "$INSTALL_DIR/streamer" 2>/dev/null || true
  fi
  chmod +x "$INSTALL_DIR/web-server" "$INSTALL_DIR/streamer" || true
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
      {"urls": ["stun:stun.l.google.com:19302","stun:stun.l.google.com:5349","stun:stun1.l.google.com:3478","stun:stun1.l.google.com:5349","stun:stun2.l.google.com:19302","stun:stun2.l.google.com:5349","stun:stun3.l.google.com:3478","stun:stun3.l.google.com:5349","stun:stun4.l.google.com:19302","stun:stun4.l.google.com:5349"]}
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
