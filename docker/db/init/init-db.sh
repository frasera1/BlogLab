#!/bin/bash
set -euo pipefail

SQLCMD="/opt/mssql-tools18/bin/sqlcmd -b -C -S db -U sa -P ${MSSQL_SA_PASSWORD}"

run_sql_file() {
  local database="$1"
  local file_path="$2"

  echo "Applying $(basename "$file_path")..."
  ${SQLCMD} -d "$database" -i "$file_path"
}

echo "Waiting for SQL Server to accept connections..."
until /opt/mssql-tools18/bin/sqlcmd -C -S db -U sa -P "${MSSQL_SA_PASSWORD}" -Q "SELECT 1" >/dev/null 2>&1; do
  sleep 2
done

db_exists=$(/opt/mssql-tools18/bin/sqlcmd -C -S db -U sa -P "${MSSQL_SA_PASSWORD}" -h -1 -W -Q "SET NOCOUNT ON; IF DB_ID(N'BlogDB') IS NULL SELECT 0 ELSE SELECT 1;" | tr -d '[:space:]')

if [ "${db_exists}" = "0" ]; then
  echo "Creating BlogDB and applying schema..."
  run_sql_file master /usr/config/init/00-create-db.sql
  run_sql_file BlogDB /usr/config/init/01-schema.sql
else
  echo "BlogDB already exists; skipping schema creation."
fi

echo "Ensuring application login exists..."
/opt/mssql-tools18/bin/sqlcmd -C -S db -U sa -P "${MSSQL_SA_PASSWORD}" \
  -d master \
  -v APP_USER="${BLOGDB_APP_USER}" APP_PASSWORD="${BLOGDB_APP_PASSWORD}" \
  -i /usr/config/init/02-create-app-login.sql

echo "Reconciling persisted schema drift..."
run_sql_file BlogDB /usr/config/init/03-reconcile-schema.sql

echo "Seeding default local admin user..."
run_sql_file BlogDB /usr/config/init/04-seed-admin-user.sql

echo "Database initialization complete."