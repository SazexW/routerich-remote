# RouteRich Remote Setup

Минимальный helper-скрипт для подключения RouteRich/OpenWrt роутера к RemoteRouteRich/Tailscale.

## Что делает

- задаёт hostname;
- проверяет/ставит `tailscale-lite`, `luci-app-tailscale`, русскую локализацию;
- задаёт сервер `https://rc.routerich.ru/`;
- включает `accept_routes=1`;
- подключает роутер через `Device Auth Key`;
- удаляет только старые конфликтные firewall-секции, созданные ранними helper-скриптами.

## Что НЕ делает

- не открывает LuCI/SSH в WAN;
- не рекламирует LAN-подсети;
- не включает Exit Node;
- не хранит ключи в GitHub.

## Запуск

```sh
wget -O /tmp/rr-remote-setup.sh 'https://raw.githubusercontent.com/SazexW/routerich-remote/refs/heads/main/rr-remote-setup.sh'
sh /tmp/rr-remote-setup.sh
```

## Подключение после установки

LuCI открывать только с устройства, которое тоже подключено к этой же RemoteRouteRich/Tailscale-сети:

```text
http://100.x.x.x/cgi-bin/luci/
```

## Ключи

Вставлять только `Device Auth Key`.

Не вставлять:
- `Management Key`
- `auth_key`, если в JSON отдельно есть `device_auth_key`
- `domain`
- `tailnet_id`
