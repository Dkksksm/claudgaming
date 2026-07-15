#!/usr/bin/env python3
"""
Google Colab Cloud Gaming Setup - Python Version
Автоматическая установка облачного гейминга в Google Colab с Tesla T4

Использование в Google Colab:
    !curl -L https://raw.githubusercontent.com/Dkksksm/claudgaming/main/colab_gaming_setup.py -o colab_gaming_setup.py
    !python colab_gaming_setup.py
"""

import os
import sys
import subprocess
import json
import time
import signal
from pathlib import Path
from typing import Optional, Tuple

# ============================================================================
# КОНФИГУРАЦИЯ
# ============================================================================

INSTALL_DIR = "/content/claudgaming-moonlight"
MOONLIGHT_RELEASE_URL = "https://github.com/kmille36/moonlight-web-remote/releases/download/0.0.2/colab-linux.zip"
CLOUDFLARED_URL = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
STEAMCMD_URL = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
MOONLIGHT_PORT = 8080
STREAMING_PORT = 47989
PIN = os.getenv("PIN", "1234")

# ============================================================================
# ЦВЕТА И ЛОГИРОВАНИЕ
# ============================================================================

class Colors:
    BLUE = '\033[1;34m'
    GREEN = '\033[1;32m'
    RED = '\033[1;31m'
    YELLOW = '\033[1;33m'
    END = '\033[0m'

def info(msg: str):
    print(f"{Colors.BLUE}[ℹ INFO]{Colors.END} {msg}")

def success(msg: str):
    print(f"{Colors.GREEN}[✓ OK]{Colors.END} {msg}")

def error(msg: str):
    print(f"{Colors.RED}[✗ ERROR]{Colors.END} {msg}", file=sys.stderr)
    sys.exit(1)

def warn(msg: str):
    print(f"{Colors.YELLOW}[⚠ WARNING]{Colors.END} {msg}")

# ============================================================================
# СИСТЕМА КОМАНД
# ============================================================================

def run_cmd(cmd: str, description: str = "", check: bool = True) -> Tuple[int, str]:
    """Запускает системную команду"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=300
        )
        if check and result.returncode != 0:
            error(f"Команда не выполнилась: {cmd}\n{result.stderr}")
        return result.returncode, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        error(f"Команда истекла по времени: {cmd}")
    except Exception as e:
        error(f"Ошибка при выполнении команды: {e}")

def run_cmd_silent(cmd: str) -> Tuple[int, str]:
    """Выполняет команду без вывода"""
    return run_cmd(cmd, check=False)

def command_exists(cmd: str) -> bool:
    """Проверяет наличие команды"""
    code, _ = run_cmd_silent(f"command -v {cmd}")
    return code == 0

# ============================================================================
# ПРОВЕРКИ
# ============================================================================

def check_colab() -> bool:
    """Проверяет наличие Google Colab среды"""
    if Path("/content").exists():
        info("✓ Обнаружена Google Colab среда")
        return True
    warn("Google Colab не обнаружена")
    return False

def check_gpu() -> bool:
    """Проверяет наличие GPU"""
    info("Проверяю GPU...")
    if command_exists("nvidia-smi"):
        code, output = run_cmd_silent("nvidia-smi --query-gpu=name,memory.total --format=csv,noheader")
        if code == 0:
            success(f"GPU обнаружена: {output.strip()}")
            return True
    warn("GPU не обнаружена")
    return False

def check_internet() -> bool:
    """Проверяет интернет-соединение"""
    info("Проверяю интернет-соединение...")
    code, _ = run_cmd_silent("curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1")
    if code == 0:
        success("Интернет доступен")
        return True
    error("Нет соединения с интернетом")

def validate_pin(pin: str) -> bool:
    """Проверяет корректность PIN"""
    if len(pin) == 4 and pin.isdigit():
        return True
    error("PIN должен быть ровно 4 цифры")

# ============================================================================
# УСТАНОВКА ЗАВИСИМОСТЕЙ
# ============================================================================

def install_dependencies():
    """Устанавливает системные зависимости"""
    info("Устанавливаю системные зависимости (это может занять 2-3 минуты)...")
    
    cmds = [
        "apt-get update -qq 2>/dev/null || true",
        "apt-get install -y -qq curl wget unzip ca-certificates gnupg2 software-properties-common lsb-release xauth xvfb procps mesa-utils --no-install-recommends 2>/dev/null || true",
        "dpkg --add-architecture i386 2>/dev/null || true",
        "apt-get update -qq 2>/dev/null || true",
        "apt-get install -y -qq libgl1-mesa-dri libgl1-mesa-glx libglapi-mesa libglu1-mesa libx11-6 libxrandr2 libxinerama1 libxcursor1 libxss1 libxcb1 libxext6 libxi6 libice6 libsm6 libfontconfig1 libfreetype6 libdbus-1-3 libnss3 libasound2 libsdl2-2.0-0 libcurl4 libcurl4-openssl-dev --no-install-recommends 2>/dev/null || true",
        "apt-get install -y -qq steamcmd cloudflared --no-install-recommends 2>/dev/null || true",
    ]
    
    for cmd in cmds:
        run_cmd(cmd, check=False)
    
    success("Зависимости установлены")

def install_steamcmd():
    """Устанавливает SteamCMD"""
    if command_exists("steamcmd"):
        success("steamcmd уже установлен")
        return
    
    info("Устанавливаю steamcmd...")
    import tempfile
    import shutil
    
    os.makedirs("/opt/steamcmd", exist_ok=True)
    
    with tempfile.TemporaryDirectory() as tmpdir:
        tar_file = os.path.join(tmpdir, "steamcmd.tar.gz")
        run_cmd(f"curl -L -s -o {tar_file} {STEAMCMD_URL}", check=True)
        run_cmd(f"tar -xzf {tar_file} -C /opt/steamcmd", check=True)
    
    os.symlink("/opt/steamcmd/steamcmd.sh", "/usr/local/bin/steamcmd")
    os.chmod("/opt/steamcmd/steamcmd.sh", 0o755)
    
    success("steamcmd установлен")

def install_steam_client():
    """Устанавливает Steam клиент для Colab"""
    info("Устанавливаю Steam клиент...")
    
    # Проверяем, есть ли Steam уже
    if command_exists("steam"):
        success("Steam клиент уже установлен")
        return
    
    # Steam требует много места и специальных зависимостей
    # В Colab лучше использовать steamcmd для управления
    info("Steam клиент не устанавливается в Colab (мало места)")
    info("Используйте steamcmd для установки игр")
    
    # Создаем скрипт для быстрого запуска steamcmd
    steam_helper = os.path.join(INSTALL_DIR, "steam_helper.sh")
    with open(steam_helper, 'w') as f:
        f.write('''#!/bin/bash
# Быстрый запуск steamcmd для установки игр
# Использование: ./steam_helper.sh app_id

APP_ID="$1"
if [ -z "$APP_ID" ]; then
    echo "Usage: ./steam_helper.sh <app_id>"
    echo "Example: ./steam_helper.sh 440  # Team Fortress 2"
    exit 1
fi

steamcmd +login anonymous +app_update $APP_ID validate +quit
''')
    os.chmod(steam_helper, 0o755)
    
    success("Steam helper создан (для установки игр)")

def install_cloudflared():
    """Устанавливает cloudflared"""
    if command_exists("cloudflared"):
        success("cloudflared уже установлен")
        return
    
    info("Устанавливаю cloudflared...")
    run_cmd(f"curl -L -s -o /usr/local/bin/cloudflared {CLOUDFLARED_URL}", check=True)
    os.chmod("/usr/local/bin/cloudflared", 0o755)
    
    success("cloudflared установлен")

def install_ngrok():
    """Устанавливает ngrok как альтернативу cloudflared"""
    if command_exists("ngrok"):
        success("ngrok уже установлен")
        return
    
    info("Устанавливаю ngrok...")
    # Скачиваем ngrok
    run_cmd("curl -L -s -o /tmp/ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz", check=False)
    
    if os.path.exists("/tmp/ngrok.zip"):
        run_cmd("tar -xzf /tmp/ngrok.zip -C /tmp && mv /tmp/ngrok /usr/local/bin/", check=False)
        os.chmod("/usr/local/bin/ngrok", 0o755)
        success("ngrok установлен")
    else:
        warn("Не удалось установить ngrok, используем cloudflared")

def start_tunnel():
    """Запускает туннель (cloudflared или ngrok)"""
    info("Запускаю туннель для публичного доступа...")
    
    log_file = os.path.join(INSTALL_DIR, "tunnel.log")
    
    # Пробуем cloudflared
    if command_exists("cloudflared"):
        cmd = f"nohup stdbuf -oL -eL cloudflared tunnel --url http://127.0.0.1:{MOONLIGHT_PORT} --no-autoupdate --loglevel info > {log_file} 2>&1 &"
        run_cmd(cmd, check=False)
        time.sleep(8)
        
        # Проверяем
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                content = f.read()
                if "trycloudflare.com" in content:
                    success("Cloudflare tunnel запущен")
                    return "cloudflared"
    
    # Альтернатива: ngrok
    if command_exists("ngrok"):
        cmd = f"nohup stdbuf -oL -eL ngrok http {MOONLIGHT_PORT} > {log_file} 2>&1 &"
        run_cmd(cmd, check=False)
        time.sleep(5)
        success("ngrok tunnel запущен")
        return "ngrok"
    
    warn("Не удалось запустить туннель")
    return None

def install_moonlight_web():
    """Устанавливает Moonlight Web"""
    info("Скачиваю и устанавливаю Moonlight Web...")
    
    import shutil
    import zipfile
    import tempfile
    
    if os.path.exists(INSTALL_DIR):
        shutil.rmtree(INSTALL_DIR)
    os.makedirs(INSTALL_DIR)
    
    with tempfile.TemporaryDirectory() as tmpdir:
        zip_file = os.path.join(tmpdir, "moonlight.zip")
        run_cmd(f"curl -L -s -o {zip_file} {MOONLIGHT_RELEASE_URL}", check=True)
        
        extract_dir = os.path.join(tmpdir, "extracted")
        os.makedirs(extract_dir)
        with zipfile.ZipFile(zip_file, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
        
        # Ищу бинарники
        streamer_path = None
        web_server_path = None
        
        if os.path.exists(os.path.join(extract_dir, "package")):
            streamer_path = os.path.join(extract_dir, "package", "streamer")
            web_server_path = os.path.join(extract_dir, "package", "web-server")
        else:
            streamer_path = os.path.join(extract_dir, "streamer")
            web_server_path = os.path.join(extract_dir, "web-server")
        
        if os.path.exists(streamer_path):
            shutil.copy(streamer_path, os.path.join(INSTALL_DIR, "streamer"))
        if os.path.exists(web_server_path):
            shutil.copy(web_server_path, os.path.join(INSTALL_DIR, "web-server"))
        
        os.chmod(os.path.join(INSTALL_DIR, "web-server"), 0o755)
        os.chmod(os.path.join(INSTALL_DIR, "streamer"), 0o755)
    
    os.makedirs(os.path.join(INSTALL_DIR, "server"), exist_ok=True)
    
    if not os.path.exists(os.path.join(INSTALL_DIR, "web-server")):
        error("Не удалось установить Moonlight Web")
    
    success(f"Moonlight Web установлен в {INSTALL_DIR}")

# ============================================================================
# КОНФИГУРАЦИЯ
# ============================================================================

def write_config():
    """Записывает конфигурацию Moonlight Web"""
    info("Записываю конфигурацию Moonlight Web...")
    
    config = {
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
            "ice_server_script": None,
            "port_range": "10000:20000",
            "nat_1to1": None,
            "network_types": ["udp4", "udp6"],
            "include_loopback_candidates": True
        },
        "web_server": {
            "bind_address": "0.0.0.0:8080",
            "certificate": None,
            "url_path_prefix": "",
            "session_cookie_secure": False,
            "session_cookie_expiration": {"secs": 86400, "nanos": 0},
            "first_login_create_admin": True,
            "first_login_assign_global_hosts": True,
            "default_user_id": None,
            "default_role_id": None,
            "forwarded_header": None
        },
        "moonlight": {
            "default_http_port": 47989,
            "pair_device_name": "claudgaming"
        },
        "streamer_path": "./streamer",
        "log": {
            "level_filter": "INFO",
            "file_path": None,
            "dev_venator": False
        },
        "default_settings": None
    }
    
    config_path = os.path.join(INSTALL_DIR, "server", "config.json")
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    success("Конфигурация записана")

# ============================================================================
# ЗАПУСК СЕРВИСОВ
# ============================================================================

def start_moonlight_web():
    """Запускает Moonlight Web server"""
    info("Запускаю Moonlight Web server...")
    
    validate_pin(PIN)
    
    os.chdir(INSTALL_DIR)
    
    log_file = os.path.join(INSTALL_DIR, "web-server.log")
    cmd = f"nohup stdbuf -oL -eL ./web-server --config-path server/config.json > {log_file} 2>&1 &"
    run_cmd(cmd, check=False)
    
    success("Moonlight Web запущен")
    time.sleep(5)  # Ждем запуск сервера
    
    # Проверяем, что сервер запустился
    if os.path.exists(log_file):
        with open(log_file, 'r') as f:
            content = f.read()
            if "error" in content.lower() or "panic" in content.lower():
                warn("Ошибка в web-server. Проверьте лог:")
                print(content[-500:])
    
    # Устанавливаем PIN через API (как в moon-pair.sh)
    info("Настраиваю PIN для Moonlight...")
    
    # Ждем, пока сервер будет готов принимать запросы
    for i in range(10):
        try:
            import urllib.request
            import ssl
            
            # Отключаем SSL проверку для localhost
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            
            # Устанавливаем PIN через API
            pin_url = f"https://localhost:{STREAMING_PORT}/api/pin"
            pin_data = json.dumps({"pin": PIN, "name": "claudgaming"}).encode()
            
            req = urllib.request.Request(
                pin_url,
                data=pin_data,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            
            # Добавляем basic auth (admin:admin)
            import base64
            credentials = base64.b64encode(b"admin:admin").decode()
            req.add_header("Authorization", f"Basic {credentials}")
            
            try:
                with urllib.request.urlopen(req, context=ctx, timeout=5) as response:
                    success(f"PIN {PIN} установлен через API")
                    return
            except Exception as e:
                if i < 9:
                    time.sleep(1)
                    continue
                warn(f"Не удалось установить PIN через API: {e}")
                warn("PIN будет установлен автоматически при первом подключении")
        except Exception as e:
            if i < 9:
                time.sleep(1)
                continue
            warn(f"Ошибка при настройке PIN: {e}")

def start_cloudflare_tunnel():
    """Запускает Cloudflare tunnel (обертка)"""
    return start_tunnel()

# ============================================================================
# ВЫВОД ИНФОРМАЦИИ
# ============================================================================

def get_tunnel_url() -> Optional[str]:
    """Получает публичный URL туннеля"""
    import re
    
    # Проверяем оба лога
    for log_name in ["cloudflared.log", "tunnel.log"]:
        log_file = os.path.join(INSTALL_DIR, log_name)
        
        for _ in range(10):
            if os.path.exists(log_file):
                with open(log_file, 'r') as f:
                    content = f.read()
                    # Cloudflare
                    match = re.search(r'https?://[^ ]+trycloudflare\.com', content)
                    if match:
                        return match.group(0)
                    # ngrok
                    match = re.search(r'https://[a-z0-9]+\.ngrok\.io', content)
                    if match:
                        return match.group(0)
            time.sleep(1)
    
    return None

def print_connection_info():
    """Выводит информацию о подключении"""
    tunnel_url = get_tunnel_url()
    
    print("\n" + "="*72)
    print("║" + " "*70 + "║")
    print("║" + "ОБЛАЧНЫЙ ГЕЙМИНГ В GOOGLE COLAB ГОТОВ К РАБОТЕ".center(70) + "║")
    print("║" + " "*70 + "║")
    print("="*72)
    print()
    
    print("📍 ИНФОРМАЦИЯ О ПОДКЛЮЧЕНИИ:")
    print("-"*72)
    print()
    print(f"  🔐 PIN для подключения Moonlight:    {PIN}")
    print(f"  🌐 Локальный адрес:                  http://127.0.0.1:{MOONLIGHT_PORT}")
    print(f"  📡 Порт стриминга Moonlight:         {STREAMING_PORT}")
    print(f"  📁 Папка установки:                  {INSTALL_DIR}")
    print()
    
    if tunnel_url:
        print(f"  🚀 ПУБЛИЧНЫЙ URL (Cloudflare):       {tunnel_url}")
        print("     ☝️ ИСПОЛЬЗУЙТЕ ЭТОТ URL для подключения из интернета!")
    else:
        print("  ⏳ Публичный URL еще не готов...")
        print(f"     Проверьте лог: {INSTALL_DIR}/cloudflared.log")
    print()
    
    print("📋 ЛОГИ:")
    print("-"*72)
    print(f"  Moonlight Web:  {INSTALL_DIR}/web-server.log")
    print(f"  Cloudflare:     {INSTALL_DIR}/cloudflared.log")
    print()
    
    print("📝 СЛЕДУЮЩИЕ ШАГИ:")
    print("-"*72)
    print()
    print("  1. Откройте публичный URL в браузере (если он уже готов)")
    print("  2. Установите игру через steamcmd:")
    print(f"     !bash {INSTALL_DIR}/steam_helper.sh 440  # Team Fortress 2")
    print(f"     !bash {INSTALL_DIR}/steam_helper.sh 740  # Cuphead")
    print("  3. Подключитесь через Moonlight клиент")
    print("  4. Запустите игры!")
    print()
    print("="*72)
    print()

# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================

def keep_alive():
    """Держит ячейку активной и показывает логи"""
    web_log = os.path.join(INSTALL_DIR, "web-server.log")
    cf_log = os.path.join(INSTALL_DIR, "cloudflared.log")
    
    last_web_line = 0
    last_cf_line = 0
    
    def read_new_lines(filepath, last_line_num):
        """Читает новые строки из файла"""
        try:
            if not os.path.exists(filepath):
                return last_line_num, []
            
            with open(filepath, 'r') as f:
                lines = f.readlines()
            
            new_lines = lines[last_line_num:]
            return len(lines), new_lines
        except Exception as e:
            return last_line_num, []
    
    # Пытаемся включить audio для поддержания активности в Colab
    try:
        from IPython.display import HTML, display
        audio_html = '''
        <audio autoplay loop style="display:none">
            <source src="https://github.com/kmille36/Colab-Cloud-Gaming/raw/refs/heads/main/silence.m4a" type="audio/mp4">
        </audio>
        '''
        display(HTML(audio_html))
        info("🔊 Включен audio для поддержания активности Colab")
    except:
        pass
    
    info("📺 Показываю логи (Ctrl+C для остановки)...")
    print()
    
    try:
        while True:
            # Читаю новые строки из логов
            last_web_line, web_lines = read_new_lines(web_log, last_web_line)
            last_cf_line, cf_lines = read_new_lines(cf_log, last_cf_line)
            
            # Выводю новые строки
            if web_lines:
                for line in web_lines:
                    print(f"{Colors.BLUE}[WEB]{Colors.END} {line.rstrip()}")
            
            if cf_lines:
                for line in cf_lines:
                    print(f"{Colors.YELLOW}[CF ]{Colors.END} {line.rstrip()}")
            
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n")
        info("Ячейка остановлена")
        return
    except Exception as e:
        warn(f"Ошибка при чтении логов: {e}")
        # Все равно держу ячейку активной
        try:
            while True:
                time.sleep(60)
        except KeyboardInterrupt:
            pass

def main():
    print()
    print("🎮 Google Colab Cloud Gaming Setup - Python Version")
    print()
    
    # Проверки
    print("━"*72)
    print("ПРОВЕРКИ")
    print("━"*72)
    check_internet()
    check_colab()
    check_gpu()
    print()
    
    # Установка
    print("━"*72)
    print("ЭТАП 1: Установка зависимостей")
    print("━"*72)
    install_dependencies()
    print()
    
    print("━"*72)
    print("ЭТАП 2: Установка компонентов")
    print("━"*72)
    install_steamcmd()
    install_steam_client()
    install_cloudflared()
    install_ngrok()
    install_moonlight_web()
    print()
    
    print("━"*72)
    print("ЭТАП 3: Конфигурация")
    print("━"*72)
    write_config()
    print()
    
    print("━"*72)
    print("ЭТАП 4: Запуск сервисов")
    print("━"*72)
    start_moonlight_web()
    start_cloudflare_tunnel()
    print()
    
    # Выводу информацию
    print_connection_info()
    
    success("Облачный гейминг запущен! 🚀")
    print()
    
    # Держу ячейку активной
    print("━"*72)
    print("ЛОГИРОВАНИЕ (активная ячейка)")
    print("━"*72)
    print()
    keep_alive()

if __name__ == "__main__":
    try:
        # В Colab запускать нужно через !
        if os.getenv("COLAB_PYTHON_RUNTIME"):
            # Colab среда
            main()
        else:
            # Локальная среда
            if os.geteuid() != 0:
                error("Этот скрипт должен запускаться от root: sudo python3 colab_gaming_setup.py")
            main()
    except KeyboardInterrupt:
        print("\n\nПрограмма прервана пользователем")
        sys.exit(0)
    except Exception as e:
        error(f"Неожиданная ошибка: {e}")
