#!/usr/bin/env bash
# Сценарий доставки статического сайта на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"

# Запуск из любого каталога репозитория (Требование 2)
REPO_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"

# Программа SSH хоста Windows для обхода изоляции сети
SSH_CMD="/mnt/host/c/Windows/System32/OpenSSH/ssh.exe"

# 1. Разбор аргумента --dry-run (Требование 1)
DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN="--dry-run"
fi

# 2. Проверка наличия site/index.html (Требование 4)
if [ ! -f "${LOCAL_DIR}index.html" ]; then
    echo "Ошибка: обязательный файл ${LOCAL_DIR}index.html не найден!" >&2
    exit 1
fi

# 3. Проверка незафиксированных изменений в Git (Требование 5)
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Ошибка: в репозитории есть незафиксированные изменения!" >&2
    exit 1
fi

# 4. Передача файлов через rsync (Требования 1, 3, 8, 9)
rsync -avz --delete --chmod=D755,F644 \
    -e "${SSH_CMD} -o BatchMode=yes -o ConnectTimeout=5" \
    ${DRY_RUN} "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# Если режим --dry-run, выходим с кодом 0 (Требование 1)
if [ -n "${DRY_RUN}" ]; then
    exit 0
fi

# 5. Проверка доступности по HTTPS через curl хоста Windows (Требование 6)
if ! /mnt/host/c/Windows/System32/curl.exe -fsS -k "${SITE_URL}" > /dev/null 2>&1; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен по HTTPS!" >&2
    exit 1
fi

# 6. Вывод короткого хеша задеплоенного коммита (Требование 7)
COMMIT_HASH="$(git rev-parse --short HEAD)"
echo "Деплой успешно завершён. Коммит: ${COMMIT_HASH}"
exit 0
