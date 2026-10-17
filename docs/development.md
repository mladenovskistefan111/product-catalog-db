# Develop & test

## Running locally

Requirements: Docker.

```bash
# build
docker build -t product-catalog-db .

# run (fresh volume ⇒ init script runs)
docker run -d --name catalog-postgres \
  -e POSTGRES_DB=productcatalog \
  -e POSTGRES_USER=catalog \
  -e POSTGRES_PASSWORD=catalog \
  -p 5432:5432 \
  product-catalog-db

# verify
docker exec -it catalog-postgres psql -U catalog -d productcatalog \
  -c "SELECT id, name, price_usd_units, categories FROM products ORDER BY id;"

# readiness
docker exec catalog-postgres pg_isready -U catalog -d productcatalog

# reset to a clean seed
docker rm -f catalog-postgres   # add `-v` if you used a named volume
```

The platform's compose file (`platform-demo-observability/docker-compose.yaml`) runs this image with a `postgres_data` volume and a `pg_isready` healthcheck, and `product-catalog-service` waits on `service_healthy`.

## Project structure

```
├── Dockerfile    # FROM postgres:17 + COPY dump.sql
├── dump.sql      # CREATE TABLE products + 9 seed rows
└── README.md
```
