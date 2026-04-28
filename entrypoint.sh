#!/bin/bash
set -e

USERNAME=robot

if [ ! -n "${HOST_UID}" ] || [ "${HOST_UID}" == "0" ]; then
  exec "$@"
  exit 0
fi

CONFLICT_USER=$(getent passwd "${HOST_UID}" | cut -d: -f1)
if [ -n "${CONFLICT_USER}" ] && [ "${CONFLICT_USER}" != "${USERNAME}" ]; then
    usermod -u 9999 "${CONFLICT_USER}" || true
    groupmod -g 9999 "${CONFLICT_USER}" || true
fi

if ! id "${USERNAME}" >/dev/null 2>&1; then
    groupadd -g "${HOST_GID}" "${USERNAME}" || true
    useradd -u "${HOST_UID}" -g "${HOST_GID}" -s /bin/bash -m  -d "/home/${USERNAME}/" "${USERNAME}"
else
    usermod -u "${HOST_UID}" -g "${HOST_GID}" "${USERNAME}"
fi

chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"
echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
exec gosu "${USERNAME}" "$@"
