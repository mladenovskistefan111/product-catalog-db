# Configuration

Standard `postgres` image variables. They are only read **on first initialisation** of an empty data directory.

| Variable | Used value | Description |
|---|---|---|
| `POSTGRES_DB` | `productcatalog` | database created on first start — **must match** the DB name in `product-catalog-service`'s `DATABASE_URL` |
| `POSTGRES_USER` | `catalog` | superuser created on first start |
| `POSTGRES_PASSWORD` | `catalog` (demo value) | superuser password — **put in a Kubernetes `Secret`** |
| `PGDATA` | `/var/lib/postgresql/data` (preset) | data directory |

If `POSTGRES_PASSWORD` is missing, the container refuses to start.

> **Important — init scripts run once.** Everything in `/docker-entrypoint-initdb.d/` only executes when the data directory is empty. If a volume already contains a database, changes to `dump.sql` (new image tag) are **ignored**. To re-seed, delete the volume/PVC (dev) or apply the change as a SQL migration.
