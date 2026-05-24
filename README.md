# RouteRich Remote Setup

Универсальный скрипт для подключения RouteRich / OpenWrt роутеров к RemoteRouteRich через Tailscale.

Скрипт предназначен для быстрой настройки удалённого доступа к LuCI и SSH по Tailscale IP вида `100.x.x.x`.

## Что делает скрипт

- запрашивает hostname роутера;
- проверяет и устанавливает необходимые пакеты;
- включает Tailscale / RemoteRouteRich;
- настраивает сервер входа `https://rc.routerich.ru/`;
- создаёт интерфейс OpenWrt `tailscale` → `tailscale0`;
- настраивает firewall-зону `tailscale`;
- подключает роутер через `device_auth_key`;
- показывает итоговый Tailscale IP.

## Требования

- Роутер на OpenWrt / RouteRich.
- Доступ в терминал роутера от `root`.
- Доступ роутера в интернет.
- JSON / ключи, полученные в панели RemoteRouteRich.

## Безопасность

В репозиторий нельзя добавлять:

- `device_auth_key`;
- `management_key`;
- JSON-файл с ключами;
- скриншоты с ключами;
- бэкапы конфигурации роутеров;
- реальные IP-адреса устройств, если репозиторий публичный.

Скрипт не содержит ключей. `device_auth_key` вводится вручную во время запуска.

## Какие данные нужны из JSON

Для подключения роутера нужен только:

```text
/device_auth_key/
```

Назначение полей:

| Поле JSON | Использование |
|---|---|
| `device_auth_key` | Вводится в скрипт на каждом подключаемом устройстве |
| `management_key` | Используется только для управления сетью в панели RemoteRouteRich |
| `auth_key` | Обычно не нужен, если есть отдельный `device_auth_key` |
| `domain` | Служебное поле |
| `tailnet_id` | Служебное поле |
| `tailnet_name` | Служебное поле |

Обычно одна сеть создаётся один раз, после чего несколько роутеров подключаются к этой же сети через один `device_auth_key`.

## Рекомендации по hostname

Используйте короткие технические имена без пробелов, подчёркиваний и точек.

Подходящие примеры:

```text
router-main
router-client-01
router-client-02
router-client-03
router-client-04
```

Нежелательные варианты:

```text
router_main
router.client.01
Router Client 01
```

## Быстрый запуск

Замените `GITHUB_USER` и `REPO_NAME` на свои значения.

```sh
wget -O /tmp/rr-remote-setup.sh 'https://raw.githubusercontent.com/GITHUB_USER/REPO_NAME/main/rr-remote-setup.sh'
sh /tmp/rr-remote-setup.sh
```

Если `wget` не скачивает HTTPS:

```sh
uclient-fetch -O /tmp/rr-remote-setup.sh 'https://raw.githubusercontent.com/GITHUB_USER/REPO_NAME/main/rr-remote-setup.sh'
sh /tmp/rr-remote-setup.sh
```

## Что вводить при запуске

Скрипт задаёт три вопроса.

### 1. Hostname роутера

Пример:

```text
router-client-01
```

### 2. Роль роутера

```text
1 = admin/main router
2 = client router
```

Роль `1` используется для основного административного роутера. Она разрешает локальным устройствам из LAN открывать удалённые Tailscale IP `100.x.x.x` через этот роутер.

Роль `2` используется для обычных удалённых роутеров. Она разрешает вход к самому роутеру через Tailscale, но не публикует его LAN-сеть.

### 3. device_auth_key

Вставляется значение `device_auth_key` из JSON RemoteRouteRich.

Не вставляйте сюда `management_key`, `auth_key`, `domain`, `tailnet_id` или `tailnet_name`.

## После установки

В конце успешной установки будет показан Tailscale IP:

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

## Что скрипт намеренно не включает

Скрипт не включает:

- `advertise-routes`;
- subnet routes;
- exit node;
- публикацию LAN-сетей вида `192.168.1.0/24`.

Это сделано специально: если несколько удалённых роутеров используют одинаковую LAN-сеть, публикация этих подсетей создаст конфликт маршрутов. Для администрирования роутеров достаточно доступа по их уникальным Tailscale IP `100.x.x.x`.

## Диагностика

Проверить статус:

```sh
tailscale status
tailscale ip -4
```

Проверить процесс:

```sh
ps w | grep -E '[t]ailscale'
```

Проверить логи:

```sh
logread -e tailscale | tail -80
```

Проверить интерфейс:

```sh
ip link show tailscale0
```
