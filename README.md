# RouteRich Remote Setup

Скрипт для подключения RouteRich/OpenWrt роутера к RemoteRouteRich/Tailscale.

## Важно

Скрипт не содержит ключей. Во время запуска нужно вставить `Device Auth Key`.

Не вставлять:
- `Management Key`
- `auth_key`, если в JSON отдельно есть `device_auth_key`
- `tailnet_id`
- `domain`

## Запуск на роутере

```sh
wget -O /tmp/rr-remote-setup.sh 'https://raw.githubusercontent.com/SazexW/routerich-remote/refs/heads/main/rr-remote-setup.sh'
sh /tmp/rr-remote-setup.sh
```

## После установки

LuCI открывать с устройства, которое тоже подключено к этой же RemoteRouteRich/Tailscale-сети:

```text
http://100.x.x.x/cgi-bin/luci/
```

Для веб-терминала через Tailscale:
`Службы -> Терминал -> Конфиг -> Интерфейс -> tailscale0`.
