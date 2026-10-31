#!/bin/sh
# Registers the admin user via the shared secret in homeserver.yaml.
# Retries while synapse is starting; stops when the user already exists.
for i in $(seq 1 30); do
  out=$(register_new_matrix_user -c /data/homeserver.yaml \
        -u "$MATRIX_ADMIN_USER" -p "$MATRIX_ADMIN_PASSWORD" --admin \
        http://synapse:8008 2>&1) && { echo "admin created"; exit 0; }
  echo "$out"
  echo "$out" | grep -qi "already" && { echo "admin exists"; exit 0; }
  sleep 5
done
echo "giving up"
exit 1
