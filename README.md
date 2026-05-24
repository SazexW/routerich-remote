# RouteRich Remote Setup v3

Публичный репозиторий для скрипта удалённого подключения RouteRich/OpenWrt к RemoteRouteRich/Tailscale.

## Что исправлено в v3

В v1/v2 скрипт создавал свою firewall-зону `firewall.tailscale` с именем `tailscale`.
На RouteRich `luci-app-tailscale` уже создаёт штатную зону `firewall.tszone` с тем же именем `tailscale`.

Из-за двух зон с одинаковым именем OpenWrt/fw4 может падать с ошибкой:

```text
Error: redefinition of symbol 'tailscale_devices'
The rendered ruleset contains errors, not doing firewall restart.
```

v3:
- удаляет старую `firewall.tailscale`;
- удаляет анонимные дубли зоны `tailscale`;
- использует штатную `firewall.tszone`;
- проверяет `fw4 check`;
- не игнорирует ошибку перезапуска firewall.

## Использование

```sh
wget -O /tmp/rr-remote-setup.sh 'RAW_URL_СКРИПТА'
sh /tmp/rr-remote-setup.sh
```

## Что вводить

- hostname: например `router-main` или `router-client-01`
- роль: `1` для main/admin, `2` для client
- ключ: именно `device_auth_key`, не `management_key`
