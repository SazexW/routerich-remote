# RouteRich Remote Setup

Скрипт для подключения RouteRich / OpenWrt роутеров к RemoteRouteRich через Tailscale.

## Важно про безопасность

В репозиторий нельзя добавлять:

- `device_auth_key`
- `management_key`
- JSON-файл с ключами
- скриншоты, где видны ключи
- бэкапы роутеров

Сам скрипт безопасен для публичного GitHub: он не содержит ключей и запрашивает `device_auth_key` вручную при запуске.

## Какие ключи из JSON нужны

JSON с `https://remote.routerich.ru` создаётся один раз для одной сети.

Использование:

| Поле JSON | Для чего |
|---|---|
| `device_auth_key` | Вставляется в скрипт на каждом роутере |
| `management_key` | Для управления панелью RemoteRouteRich, в роутеры не вставляется |
| `auth_key` | Не используем, если есть отдельный `device_auth_key` |
| `domain`, `tailnet_id`, `tailnet_name` | Служебная информация, в скрипт не нужна |

Все роутеры подключаются к одной сети через один `device_auth_key`.

## Имена роутеров

Используем hostname без `_` и без `.`:

| Клиентское имя | Hostname для скрипта |
|---|---|
| main_Sazex | `main-sazex` |
| Lina_routerich | `lina-routerich` |
| Ave_routerich | `ave-routerich` |
| Kost_routerich | `kost-routerich` |
| Bog_routerich | `bog-routerich` |

## Быстрый запуск на роутере

Заменить `GITHUB_USER` на свой GitHub-логин.

```sh
wget -O /tmp/rr-remote-setup.sh 'https://raw.githubusercontent.com/GITHUB_USER/routerich-remote/main/rr-remote-setup.sh'
sh /tmp/rr-remote-setup.sh
```

Если `wget` на прошивке не скачивает HTTPS, использовать:

```sh
uclient-fetch -O /tmp/rr-remote-setup.sh 'https://raw.githubusercontent.com/GITHUB_USER/routerich-remote/main/rr-remote-setup.sh'
sh /tmp/rr-remote-setup.sh
```

## Ответы в скрипте

### Для main

```text
Hostname: main-sazex
Роль: 1
device_auth_key: вставить значение device_auth_key из JSON
```

### Для Lina

```text
Hostname: lina-routerich
Роль: 2
device_auth_key: вставить значение device_auth_key из JSON
```

### Для Ave

```text
Hostname: ave-routerich
Роль: 2
device_auth_key: вставить значение device_auth_key из JSON
```

### Для Kost

```text
Hostname: kost-routerich
Роль: 2
device_auth_key: вставить значение device_auth_key из JSON
```

### Для Bog

```text
Hostname: bog-routerich
Роль: 2
device_auth_key: вставить значение device_auth_key из JSON
```

## После установки

В конце скрипт покажет:

```text
Tailscale IP: 100.x.x.x
```

LuCI открывается так:

```text
http://100.x.x.x
```

SSH:

```sh
ssh root@100.x.x.x
```

## Что скрипт НЕ делает

Он намеренно не включает:

- `advertise-routes`
- subnet routes
- exit-node
- маршрутизацию `192.168.1.0/24`

Причина: у всех роутеров одинаковая LAN-сеть `192.168.1.0/24`, поэтому доступ делаем к самим роутерам по их уникальным Tailscale IP `100.x.x.x`.
