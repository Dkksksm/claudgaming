# claudgaming

Скрипт для установки и запуска облачной игровой среды с Steam, Moonlight Web и Cloudflare Tunnel.

Файл установки: `clab_claud_gaming.sh`

Пример использования:

```bash
sudo bash clab_claud_gaming.sh install
sudo bash clab_claud_gaming.sh run
```

После выполнения `install` веб-интерфейс Moonlight будет доступен на порту `8080`, а стриминг Moonlight — на порту `47989`.

Если `cloudflared` доступен, скрипт попытается поднять tunnel и вывести URL `trycloudflare.com`.

### Запуск из Google Colab одним скриптом

```bash
cd /content
curl -L https://raw.githubusercontent.com/Dkksksm/claudgaming/main/colab_gaming.sh -o /content/colab_gaming.sh
chmod +x /content/colab_gaming.sh
sudo /content/colab_gaming.sh
```

Если хотите задать PIN заранее:

```bash
export PIN=1234
sudo /content/colab_gaming.sh
```

Для Google Colab с Tesla T4:

```bash
cd /content
git clone https://github.com/Dkksksm/claudgaming.git
cd claudgaming
sudo bash clab_claud_gaming.sh install
sudo bash clab_claud_gaming.sh run
```

Если Steam не установлен, используйте `sudo bash clab_claud_gaming.sh steamcmd` для установки/входа.
