podman run -d --rm \
  --name dbt-postgres \
  -e POSTGRES_USER=dbt \
  -e POSTGRES_PASSWORD=dbt \
  -e POSTGRES_DB=ecommerce \
  -p 5432:5432 \
  -v dbt-postgres-data:/var/lib/postgresql \
  postgres:18