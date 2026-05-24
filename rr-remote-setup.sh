#!/bin/sh
# RouteRich RemoteRouteRich/Tailscale setup for OpenWrt/RouteRich
# v3: no duplicate firewall zones; cleans old broken firewall.tailscale from earlier versions.
# Safe for public GitHub: contains NO keys.

set -u

LOGIN_SERVER="https://rc.routerich.ru/"

fail() {
  echo "ОШИБКА: $1"
  exit 1
}

hr() {
  echo
  echo "------------------------------------------------------------"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "нет команды: $1"
}

cleanup_duplicate_tailscale_zones() {
  echo "Чищу возможные дубли firewall-зоны tailscale..."

  # Old custom zone from v1/v2 scripts. RouteRich/luci-app-tailscale already creates tszone.
  uci -q delete firewall.tailscale

  # Delete anonymous zones also named tailscale, if any.
  # Do it in loop because @zone indexes shift after delete.
  while true; do
    ZONE_REF="$(uci show firewall 2>/dev/null | sed -n "s/^firewall\.\(@zone\[[0-9][0-9]*\]\)\.name='tailscale'.*/\1/p" | head -n 1)"
    [ -n "$ZONE_REF" ] || break
    echo "Удаляю дубль firewall.$ZONE_REF"
    uci -q delete "firewall.$ZONE_REF"
  done

  # Delete old forwardings created by earlier versions of this helper.
  uci -q delete firewall.lan_to_tailscale
  uci -q delete firewall.tailscale_to_lan

  # Ensure the official/single zone exists.
  uci -q get firewall.tszone >/dev/null 2>&1 || uci set firewall.tszone='zone'
  uci set firewall.tszone.name='tailscale'
  uci set firewall.tszone.input='ACCEPT'
  uci set firewall.tszone.output='ACCEPT'
  uci set firewall.tszone.forward='ACCEPT'
  uci set firewall.tszone.device='tailscale+'

  # Ensure useful default forwardings through official zone.
  # These sections are used by RouteRich/luci-app-tailscale; setting them is idempotent.
  uci -q get firewall.lan_ac_ts >/dev/null 2>&1 || uci set firewall.lan_ac_ts='forwarding'
  uci set firewall.lan_ac_ts.src='lan'
  uci set firewall.lan_ac_ts.dest='tailscale'

  uci -q get firewall.ts_ac_lan >/dev/null 2>&1 || uci set firewall.ts_ac_lan='forwarding'
  uci set firewall.ts_ac_lan.src='tailscale'
  uci set firewall.ts_ac_lan.dest='lan'

  uci commit firewall

  echo "Проверяю firewall..."
  if command -v fw4 >/dev/null 2>&1; then
    fw4 check || fail "fw4 check нашёл ошибку в firewall. Пришли вывод выше."
  fi

  /etc/init.d/firewall restart || fail "firewall не перезапустился. Пришли вывод ошибки."
}

echo "RouteRich RemoteRouteRich setup v3"
echo "Секреты НЕ хранятся в скрипте."
echo "Нужен device_auth_key из JSON, полученного на https://remote.routerich.ru"
echo

printf "Hostname роутера, например router-main или router-client-01: "
read -r HOSTNAME_SAFE
[ -n "$HOSTNAME_SAFE" ] || fail "hostname пустой"

case "$HOSTNAME_SAFE" in
  *" "*|*"_"*|*"."*)
    fail "hostname не должен содержать пробелы, подчёркивания '_' или точки '.'. Используй дефис."
    ;;
esac

echo
echo "Роль роутера:"
echo "  1 = main/admin"
echo "  2 = client"
echo "Примечание: в v3 firewall настраивается одинаково через штатную зону tszone,"
echo "потому что RouteRich/luci-app-tailscale уже создаёт нужную зону tailscale."
printf "Выбери роль [1/2, по умолчанию 2]: "
read -r ROUTER_ROLE
[ -n "$ROUTER_ROLE" ] || ROUTER_ROLE="2"
case "$ROUTER_ROLE" in
  1) ROLE_NAME="main-admin" ;;
  2) ROLE_NAME="client" ;;
  *) fail "роль должна быть 1 или 2" ;;
esac

echo
echo "Вставляется именно device_auth_key."
echo "НЕ management_key."
echo "НЕ auth_key, если в JSON отдельно есть device_auth_key."
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
command -v tailscale >/dev/null 2>&1 || fail "команда tailscale не найдена."
tailscale version || fail "tailscale установлен, но не запускается"

hr
echo "4. Включаю Tailscale"
uci -q get tailscale.settings >/dev/null 2>&1 || uci set tailscale.settings='tailscale'
uci set tailscale.settings.enabled='1'
uci set tailscale.settings.login_server="$LOGIN_SERVER"
uci set tailscale.settings.accept_dns='0'
uci set tailscale.settings.accept_routes='0'
uci commit tailscale

/etc/init.d/tailscale enable || true
/etc/init.d/tailscale restart || /etc/init.d/tailscale start || true
sleep 3

ps w | grep -E '[t]ailscaled' >/dev/null 2>&1 || {
  echo "ПРЕДУПРЕЖДЕНИЕ: tailscaled не найден. Последние логи:"
  logread -e tailscale | tail -80 2>/dev/null || true
}

hr
echo "5. Интерфейс OpenWrt tailscale -> tailscale0"
uci -q delete network.tailscale
uci set network.tailscale='interface'
uci set network.tailscale.proto='none'
uci set network.tailscale.device='tailscale0'
uci commit network
/etc/init.d/network reload || true

hr
echo "6. Firewall: чистка дублей и штатная зона tszone"
cleanup_duplicate_tailscale_zones

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
    echo "Если видишь ссылку https://rc.routerich.ru/a/r/... — device_auth_key не принят или пустой/не тот."
    exit 1
  }

hr
echo "8. Проверка"
sleep 5
TS_IP="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"

[ -n "$TS_IP" ] || {
  echo "Tailscale IP не получен."
  tailscale status 2>/dev/null || true
  logread -e tailscale | tail -80 2>/dev/null || true
  exit 1
}

echo "ГОТОВО."
echo "Hostname: $HOSTNAME_SAFE"
echo "Role: $ROLE_NAME"
echo "Tailscale IP: $TS_IP"
echo
echo "LuCI: http://$TS_IP"
echo "SSH:  ssh root@$TS_IP"
echo
tailscale status || true
