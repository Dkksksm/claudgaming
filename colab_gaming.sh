#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Dkksksm/claudgaming.git"
REPO_DIR="${REPO_DIR:-/content/claudgaming}"
INSTALL_SCRIPT="clab_claud_gaming.sh"
PIN="${PIN:-}"

info() { echo -e "\e[1;34m[INFO]\e[0m $*"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

clone_repo() {
  if [ -d "$REPO_DIR/.git" ]; then
    info "Обновляю репозиторий $REPO_DIR"
    if [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
      info "Найдены локальные изменения, очищаю рабочую папку"
      git -C "$REPO_DIR" reset --hard HEAD
      git -C "$REPO_DIR" clean -fd
    fi
    if ! git -C "$REPO_DIR" pull --rebase; then
      info "Не удалось обновить репозиторий, клонирую заново"
      rm -rf "$REPO_DIR"
      git clone "$REPO_URL" "$REPO_DIR"
    fi
  else
    info "Клонирую репозиторий в $REPO_DIR"
    rm -rf "$REPO_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

download_repo_tarball() {
  info "Git не установлен, загружаю архив репозитория"
  rm -rf "$REPO_DIR"
  mkdir -p "$REPO_DIR"
  curl -L "https://github.com/Dkksksm/claudgaming/archive/refs/heads/main.tar.gz" | tar xz --strip-components=1 -C "$REPO_DIR"
}

ensure_repo() {
  if command -v git >/dev/null 2>&1; then
    clone_repo
  else
    download_repo_tarball
  fi
}

ensure_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo env"
    else
      error "Требуются root-права или sudo для установки."
    fi
  else
    SUDO="env"
  fi
}

prompt_pin() {
  if [ -z "$PIN" ] && [ -t 0 ]; then
    read -rp "Введите PIN для подключения Moonlight (4 цифры, default 1234): " PIN
  fi
  PIN="${PIN:-1234}"
  if ! [[ "$PIN" =~ ^[0-9]{4}$ ]]; then
    error "PIN должен быть ровно 4 цифры."
  fi
}

main() {
  info "Запускаю скрипт Colab для Claud Gaming"
  ensure_root
  ensure_repo
  cd "$REPO_DIR"
  chmod +x "$INSTALL_SCRIPT"

  info "Запускаю установку зависимостей и Moonlight Web"
  $SUDO bash "$INSTALL_SCRIPT" install

  prompt_pin

  info "Запускаю Moonlight Web и Cloudflare tunnel"
  MOONLIGHT_PIN="$PIN" $SUDO bash "$INSTALL_SCRIPT" run

  local local_ip
  local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

  echo
  echo "Готово. Moonlight Web доступен по адресу: http://$local_ip:8080"
  echo "PIN для подключения: $PIN"
  echo "Порт Moonlight: 47989"
  echo "Если tunnel Cloudflare поднялся, ищите URL в $REPO_DIR/claudgaming-moonlight/cloudflared.log"
}

main "$@"
