# claudgaming

🎮 **Облачный гейминг в Google Colab с Tesla T4**

Полностью автоматизированная установка Steam, Moonlight Web и Cloudflare Tunnel для стриминга игр.

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
- ✅ SteamCMD для установки игр
- ✅ Moonlight Web для стриминга
- ✅ Cloudflare Tunnel для публичного доступа
- ✅ GPU поддержка (Tesla T4)
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
| `PIN` | `1234` | PIN для подключения Moonlight |
| `INSTALL_DIR` | `/content/claudgaming-moonlight` | Папка установки |

## 📊 Что произойдет

1. Проверка GPU и интернета
2. Установка системных зависимостей
3. Скачивание и установка SteamCMD, cloudflared, Moonlight Web
4. Запуск Moonlight Web сервера
5. Запуск Cloudflare Tunnel для публичного доступа
6. Вывод информации подключения с публичным URL

## 🔗 Результат

После установки вы получите:

```
🔐 PIN для подключения Moonlight:    1234
🌐 Локальный адрес:                  http://127.0.0.1:8080
📡 Порт стриминга Moonlight:         47989
🚀 ПУБЛИЧНЫЙ URL (Cloudflare):       https://xxxxx.trycloudflare.com
```

## 📖 Следующие шаги

1. Откройте публичный URL в браузере
2. Установите Steam через steamcmd
3. Подключитесь к Moonlight через клиент
4. Запустите игры!

## 📋 Системные требования

- Google Colab с Tesla T4 GPU
- Интернет-соединение
- ~10 GB свободного места
