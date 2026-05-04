#!/bin/bash
if [ "$(stat -c '%U:%G' /home/dev/jetpack/node_modules)" != "dev:dev" ]; then
	chown -R dev:dev /home/dev/jetpack/node_modules
fi
# Align the container's docker group GID with the mounted socket's GID so that
# 'dev' (added to the docker group in the Dockerfile) can actually access the socket.
if [ -S /var/run/docker.sock ]; then
	SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
	groupmod -g "$SOCKET_GID" docker 2>/dev/null || true
fi
exec gosu dev "$@"
