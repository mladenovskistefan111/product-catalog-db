# product-catalog-db

Postgres database image for the product catalog service.
Contains the products table schema and seed data baked in.

## Build
```bash
docker build -t catalog-postgres .
```

## Run
```bash
docker run -d \
  --name catalog-postgres \
  -e POSTGRES_DB=productcatalog \
  -e POSTGRES_USER=catalog \
  -e POSTGRES_PASSWORD=catalog \
  -p 5432:5432 \
  catalog-postgres
```

## Verify
```bash
docker exec -it catalog-postgres psql -U catalog -d productcatalog -c "SELECT id, name FROM products;"
```