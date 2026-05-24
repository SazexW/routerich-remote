#!/bin/sh
# RouteRich RemoteRouteRich/Tailscale setup for OpenWrt/RouteRich
# Safe for public GitHub: this file contains NO keys.
# It asks for device_auth_key at runtime and does not save it to the repository.

set -u

LOGIN_SERVER="https://rc.routerich.ru/"

hr() {
  echo
  echo "------------------------------------------------------------"
}

fail() {
  echo "ОШИБКА: $1"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "нет команды: $1"
}

echo "RouteRich RemoteRouteRich setup"
echo "Секреты НЕ хранятся в скрипте."
echo "Нужен только device_auth_key из JSON, полученного на https://remote.routerich.ru"
echo

printf "Hostname роутера, например main-sazex или lina-routerich: "
read -r HOSTNAME_SAFE

[ -n "$HOSTNAME_SAFE" ] || fail "hostname пустой"

case "$HOSTNAME_SAFE" in
  *" "*|*"_"*|*"."*)
    fail "hostname не должен содержать пробелы, подчёркивания '_' или точки '.'. Используй дефис: lina-routerich"
    ;;
esac

echo
echo "Роль роутера:"
echo "  1 = main/admin роутер: разрешить LAN -> Tailscale, чтобы устройства твоей домашней LAN открывали удалённые 100.x.x.x"
echo "  2 = client роутер: разрешить вход к самому роутеру через Tailscale, но НЕ маршрутизировать его LAN"
printf "Выбери роль [1/2, по умолчанию 2]: "
read -r ROUTER_ROLE
[ -n "$ROUTER_ROLE" ] || ROUTER_ROLE="2"

case "$ROUTER_ROLE" in
  1) ROLE_NAME="main-admin" ;;
  2) ROLE_NAME="client" ;;
  *) fail "роль должна быть 1 или 2" ;;
esac

echo
echo "Сейчас вставляется именно device_auth_key."
echo "НЕ management_key."
echo "НЕ auth_key, если в JSON отдельно есть device_auth_key."
echo "НЕ domain / tailnet_id / tailnet_name."
printf "Вставь device_auth_key и нажми Enter: "
read -r DEVICE_AUTH_KEY

[ -n "$DEVICE_AUTH_KEY" ] || fail "device_auth_key пустой"

hr
echo "1. Проверяю базовые команды"
need_cmd uci
need_cmd opkg

hr
echo "2. Настраиваю hostname: $HOSTNAME_SAFE"
uci set system.@system[0].hostname="$HOSTNAME_SAFE"
uci commit system
printf '%s\n' "$HOSTNAME_SAFE" > /proc/sys/kernel/hostname 2>/dev/null || true

echo "UCI hostname: $(uci get system.@system[0].hostname 2>/dev/null || echo '?')"
echo "Kernel hostname: $(cat /proc/sys/kernel/hostname 2>/dev/null || echo '?')"

hr
echo "3. Проверяю/устанавливаю пакеты"
opkg update || echo "ПРЕДУПРЕЖДЕНИЕ: opkg update не завершился успешно. Продолжаю, если пакеты уже стоят."
opkg install ca-bundle || true
opkg install tailscale-lite luci-app-tailscale luci-i18n-tailscale-ru || true

command -v tailscale >/dev/null 2>&1 || fail "команда tailscale не найдена. Проверь пакеты tailscale-lite/luci-app-tailscale."

echo
tailscale version || fail "tailscale установлен, но не запускается"

hr
echo "4. Включаю Tailscale в UCI"
uci -q get tailscale.settings >/dev/null 2>&1 || uci set tailscale.settings='tailscale'
uci set tailscale.settings.enabled='1'
uci set tailscale.settings.login_server="$LOGIN_SERVER"
uci set tailscale.settings.accept_dns='0'
uci set tailscale.settings.accept_routes='0'
uci commit tailscale

/etc/init.d/tailscale enable || true
/etc/init.d/tailscale restart || /etc/init.d/tailscale start || true
sleep 3

if ! ps w | grep -E '[t]ailscaled' >/dev/null 2>&1; then
  echo "ПРЕДУПРЕЖДЕНИЕ: процесс tailscaled не найден после запуска."
  echo "Последние логи:"
  logread -e tailscale | tail -80 2>/dev/null || true
else
  echo "tailscaled запущен."
fi

hr
echo "5. Создаю интерфейс OpenWrt: tailscale -> tailscale0"
uci -q delete network.tailscale
uci set network.tailscale='interface'
uci set network.tailscale.proto='none'
uci set network.tailscale.device='tailscale0'
uci commit network
/etc/init.d/network reload || true

hr
echo "6. Настраиваю firewall для роли: $ROLE_NAME"
uci -q delete firewall.tailscale
uci set firewall.tailscale='zone'
uci set firewall.tailscale.name='tailscale'
uci add_list firewall.tailscale.network='tailscale'
uci set firewall.tailscale.input='ACCEPT'
uci set firewall.tailscale.output='ACCEPT'
uci set firewall.tailscale.mtu_fix='1'

uci -q delete firewall.lan_to_tailscale
uci -q delete firewall.tailscale_to_lan

if [ "$ROUTER_ROLE" = "1" ]; then
  # Main/admin router: allow local LAN clients to open remote Tailscale IPs via this router.
  uci set firewall.tailscale.forward='ACCEPT'
  uci set firewall.tailscale.masq='1'

  uci set firewall.lan_to_tailscale='forwarding'
  uci set firewall.lan_to_tailscale.src='lan'
  uci set firewall.lan_to_tailscale.dest='tailscale'
else
  # Client router: allow Tailscale input to this router only; do not expose/route its LAN.
  uci set firewall.tailscale.forward='REJECT'
  uci set firewall.tailscale.masq='0'
fi

uci commit firewall
/etc/init.d/firewall restart || true

hr
echo "7. Подключаю к RemoteRouteRich"
tailscale up \
  --reset \
  --login-server="$LOGIN_SERVER" \
  --auth-key="$DEVICE_AUTH_KEY" \
  --hostname="$HOSTNAME_SAFE" \
  --accept-dns=false || {
    echo
    echo "tailscale up завершился с ошибкой."
    echo "Если видишь ссылку https://rc.routerich.ru/a/r/... — значит device_auth_key не принят или пустой/не тот."
    echo "Проверь, что вставляешь device_auth_key из JSON."
    exit 1
  }

hr
echo "8. Проверка"
sleep 5

TS_IP="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"

if [ -z "$TS_IP" ]; then
  echo "Tailscale IP не получен."
  echo
  echo "Диагностика:"
  tailscale status 2>/dev/null || true
  logread -e tailscale | tail -80 2>/dev/null || true
  exit 1
fi

echo "ГОТОВО."
echo "Hostname: $HOSTNAME_SAFE"
echo "Role: $ROLE_NAME"
echo "Tailscale IP: $TS_IP"
echo
echo "Открыть LuCI:"
echo "  http://$TS_IP"
echo
echo "SSH:"
echo "  ssh root@$TS_IP"
echo
echo "Статус:"
tailscale status || true
