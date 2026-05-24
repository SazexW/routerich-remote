#!/bin/sh
# RouteRich RemoteRouteRich/Tailscale setup helper
# v5-guide: минимально по гайду RouteRich.
# В скрипте НЕТ ключей.

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

clean_old_helper_firewall() {
  echo "Чищу только старые firewall-секции, созданные ранними версиями helper-скрипта..."
  uci -q delete firewall.tailscale
  uci -q delete firewall.lan_to_tailscale
  uci -q delete firewall.tailscale_to_lan
  uci commit firewall

  if command -v fw4 >/dev/null 2>&1; then
    fw4 check || fail "fw4 check нашёл ошибку в firewall. Пришли вывод выше."
  fi

  /etc/init.d/firewall restart || fail "firewall не перезапустился. Пришли вывод ошибки."
}

echo "RouteRich RemoteRouteRich setup v5-guide"
echo "Скрипт не содержит ключей."
echo "Нужен Device Auth Key из JSON, полученного на https://remote.routerich.ru"
echo

printf "Hostname роутера, например router-main или router-client-01: "
read -r HOSTNAME_SAFE

[ -n "$HOSTNAME_SAFE" ] || fail "hostname пустой"

case "$HOSTNAME_SAFE" in
  *" "*|*"_"*|*"."*)
    fail "hostname не должен содержать пробелы, подчёркивания '_' или точки '.'. Используй дефис."
    ;;
esac

if ! printf '%s' "$HOSTNAME_SAFE" | grep -Eq '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'; then
  fail "hostname должен содержать только a-z, 0-9 и дефис; начинаться и заканчиваться буквой/цифрой."
fi

echo
echo "Вставляется именно Device Auth Key."
echo "НЕ Management Key."
echo "НЕ auth_key, если в JSON отдельно есть device_auth_key."
printf "Вставь Device Auth Key и нажми Enter: "
read -r DEVICE_AUTH_KEY

[ -n "$DEVICE_AUTH_KEY" ] || fail "Device Auth Key пустой"

hr
echo "1. Проверяю базовые команды"
need_cmd uci
need_cmd opkg

hr
echo "2. Настраиваю hostname: $HOSTNAME_SAFE"
uci set system.@system[0].hostname="$HOSTNAME_SAFE"
uci commit system
printf '%s\n' "$HOSTNAME_SAFE" > /proc/sys/kernel/hostname 2>/dev/null || true

echo "UCI hostname:    $(uci get system.@system[0].hostname 2>/dev/null || echo '?')"
echo "Kernel hostname: $(cat /proc/sys/kernel/hostname 2>/dev/null || echo '?')"

hr
echo "3. Проверяю/устанавливаю пакеты"
opkg update || echo "ПРЕДУПРЕЖДЕНИЕ: opkg update не завершился успешно. Продолжаю, если пакеты уже стоят."

# На RouteRich используется tailscale-lite. Полный пакет tailscale НЕ ставим.
opkg install ca-bundle || true
opkg install tailscale-lite luci-app-tailscale luci-i18n-tailscale-ru || true

command -v tailscale >/dev/null 2>&1 || fail "команда tailscale не найдена. Проверь tailscale-lite."
tailscale version || fail "tailscale установлен, но не запускается"

hr
echo "4. Настраиваю /etc/config/tailscale"
uci -q get tailscale.settings >/dev/null 2>&1 || uci set tailscale.settings='tailscale'
uci set tailscale.settings.enabled='1'
uci set tailscale.settings.login_server="$LOGIN_SERVER"
uci set tailscale.settings.accept_dns='0'

# По гайду RouteRich для ZeroBlock/Podkop нужно включать Accept Routes.
# Для обычного LuCI/SSH это не критично, но безопасно оставить включённым в вашей сети.
uci set tailscale.settings.accept_routes='1'

uci commit tailscale

/etc/init.d/tailscale enable || true
/etc/init.d/tailscale restart || /etc/init.d/tailscale start || true
sleep 3

if ! ps w | grep -E '[t]ailscaled' >/dev/null 2>&1; then
  echo "ПРЕДУПРЕЖДЕНИЕ: tailscaled не найден после запуска."
  echo "Последние логи:"
  logread -e tailscale | tail -80 2>/dev/null || true
fi

hr
echo "5. Чищу старые конфликтные секции от предыдущих helper-скриптов"
clean_old_helper_firewall

hr
echo "6. Подключаю к RemoteRouteRich"
tailscale up \
  --reset \
  --login-server="$LOGIN_SERVER" \
  --auth-key="$DEVICE_AUTH_KEY" \
  --hostname="$HOSTNAME_SAFE" \
  --accept-dns=false \
  --accept-routes || {
    echo
    echo "tailscale up завершился с ошибкой."
    echo "Если видишь ссылку https://rc.routerich.ru/a/r/... — Device Auth Key не принят или пустой/не тот."
    exit 1
  }

hr
echo "7. Проверка"
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
echo "Tailscale IP: $TS_IP"
echo
echo "LuCI открывать с ПК/телефона, который тоже подключён к RemoteRouteRich/Tailscale:"
echo "  http://$TS_IP/cgi-bin/luci/"
echo
echo "SSH:"
echo "  ssh root@$TS_IP"
echo
echo "Для веб-терминала по Tailscale в LuCI выбери:"
echo "  Службы -> Терминал -> Конфиг -> Интерфейс -> tailscale0"
echo
tailscale status || true
