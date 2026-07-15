# claudgaming

🎮 **Облачный гейминг в Google Colab с Tesla T4**

Полностью автоматизированная установка Steam, Moonlight Web и туннеля для стриминга игр.

## 🚀 Быстрый старт в Google Colab (Python ячейка)

**Самый простой способ - скопируйте это в ячейку Python:**

```python
!curl -L https://raw.githubusercontent.com/Dkksksm/claudgaming/main/colab_gaming_setup.py -o /tmp/colab_gaming_setup.py
!python3 /tmp/colab_gaming_setup.py
```

**С кастомным PIN:**

```python
import os
os.environ["PIN"] = "5555"
!python3 /tmp/colab_gaming_setup.py
```

## 📋 Что входит

- ✅ Автоматическая установка зависимостей
- ✅ SteamCMD + steam_helper.sh для установки игр
- ✅ Moonlight Web для стриминга
- ✅ Cloudflare Tunnel или ngrok для публичного доступа
- ✅ GPU поддержка (Tesla T4)
- ✅ Автоматический PIN через API
- ✅ Audio для поддержания активности Colab
- ✅ Красивый вывод и логирование

## 📝 Файлы

- **`colab_gaming_setup.py`** — Python скрипт для Google Colab (рекомендуется)
- **`google_colab_gaming.sh`** — Bash скрипт для локального использования
- **`clab_claud_gaming.sh`** — Полный bash скрипт с функциями install/run
- **`colab_gaming.sh`** — Bash одностроник для Colab

## 🎯 Использование

### Google Colab (Python, рекомендуется)

В новой ячейке:

```python
!curl -L https://raw.githubusercontent.com/Dkksksm/claudgaming/main/colab_gaming_setup.py -o /tmp/colab_gaming_setup.py
!python3 /tmp/colab_gaming_setup.py
```

### Linux/Debian (Bash)

```bash
sudo bash google_colab_gaming.sh
```

С кастомным PIN:

```bash
PIN=1234 sudo bash google_colab_gaming.sh
```

## ⚙️ Конфигурация

| Переменная | Значение по умолчанию | Описание |
|-----------|----------------------|---------|
| `PIN` | `1234` | PIN для подключения Moonlight (4 цифры) |
| `INSTALL_DIR` | `/content/claudgaming-moonlight` | Папка установки |

## 📊 Что произойдет

1. Проверка GPU и интернета
2. Установка системных зависимостей
3. Скачивание и установка SteamCMD, cloudflared, Moonlight Web
4. Создание steam_helper.sh для установки игр
5. Запуск Moonlight Web сервера
6. Автоматическая установка PIN через API
7. Запуск туннеля (Cloudflare или ngrok)
8. Вывод информации подключения с публичным URL

## 🔗 Результат

После установки вы получите:

```
🔐 PIN для подключения Moonlight:    1234
🌐 Локальный адрес:                  http://127.0.0.1:8080
📡 Порт стриминга Moonlight:         47989
🚀 ПУБЛИЧНЫЙ URL (Cloudflare/ngrok):  https://xxxxx.trycloudflare.com
```

## 🎮 Установка игр через SteamCMD

После запуска скрипта используйте `steam_helper.sh`:

```python
# Team Fortress 2
!bash /content/claudgaming-moonlight/steam_helper.sh 440

# Cuphead
!bash /content/claudgaming-moonlight/steam_helper.sh 268910

# Counter-Strike 2
!bash /content/claudgaming-moonlight/steam_helper.sh 730
```

## 📖 Следующие шаги

1. Откройте публичный URL в браузере
2. Установите игру через steam_helper.sh
3. Подключитесь к Moonlight через клиент (используйте PIN)
4. Запустите игры!

## 📋 Системные требования

- Google Colab с Tesla T4 GPU
- Интернет-соединение
- ~10 GB свободного места
