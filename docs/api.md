# API

[`Dockerfile`](https://github.com/platform-boutique/app-product-catalog-db/tree/main/Dockerfile):

```dockerfile
FROM postgres:17
COPY dump.sql /docker-entrypoint-initdb.d/001_init.sql
```

That's all — there is no custom entrypoint, no config, no extensions. The image runs as the stock `postgres` entrypoint (starts as root, then drops to the `postgres` user via `gosu`). It declares `EXPOSE 5432`.

### Schema (`products`)

| Column | Type | Notes |
|---|---|---|
| `id` | `TEXT` | primary key, e.g. `OLJCESPC7Z` |
| `name` | `TEXT NOT NULL` | |
| `description` | `TEXT NOT NULL` | |
| `picture` | `TEXT NOT NULL` | relative URL, e.g. `/static/img/products/sunglasses.jpg` (served by `frontend`) |
| `price_usd_currency_code` | `TEXT NOT NULL DEFAULT 'USD'` | |
| `price_usd_units` | `BIGINT NOT NULL DEFAULT 0` | |
| `price_usd_nanos` | `INT NOT NULL DEFAULT 0` | |
| `categories` | `TEXT NOT NULL DEFAULT ''` | comma-separated, e.g. `clothing,tops` |

The script uses `CREATE TABLE IF NOT EXISTS` and `INSERT … ON CONFLICT (id) DO NOTHING`, so re-running it is harmless.

### Seed data (9 products)

| ID | Name | USD | Categories |
|---|---|---|---|
| `OLJCESPC7Z` | Sunglasses | 19.99 | accessories |
| `66VCHSJNUP` | Tank Top | 18.99 | clothing, tops |
| `1YMWWN1N4O` | Watch | 109.99 | accessories |
| `L9ECAV7KIM` | Loafers | 89.99 | footwear |
| `2ZYFJ3GM2N` | Hairdryer | 24.99 | hair, beauty |
| `0PUK6V6EV0` | Candle Holder | 18.99 | decor, home |
| `LS4PSXUNUM` | Salt & Pepper Shakers | 18.49 | kitchen |
| `9SIQT8TOJO` | Bamboo Glass Jar | 5.49 | kitchen |
| `6E92ZMYYFZ` | Mug | 8.99 | kitchen |
