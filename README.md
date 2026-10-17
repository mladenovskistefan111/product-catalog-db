# product-catalog-db

> **Temporary.** This image exists only for local testing (kind). It is hand-built, has no pipeline and no signature, and is replaced by **Amazon RDS** when the application is deployed on AWS; at that point this repository, its Helm chart and the allow-list entry in the Helm CI are deleted.

The PostgreSQL database image for the platform-demo product catalog. It is the official `postgres:17` image with a single init script baked in that creates the `products` table and seeds 9 products. It is read by exactly one consumer: `product-catalog-service`.

Part of the [platform-demo](https://github.com/platform-boutique) platform — microservices, observability (LGTM stack), GitOps (Argo CD), policy enforcement (Kyverno), infrastructure provisioning (Crossplane) and an internal developer portal (Backstage). See the master `README.md` in the platform-demo root for the whole-system view.

## At a glance

| | |
|---|---|
| **Engine** | PostgreSQL 17 (`postgres:17`, currently 17.9 on Debian) |
| **Image** | `mladenovskistefan/product-catalog-db` (tag `latest`; consider pinning) |
| **Port** | `5432` (PostgreSQL wire protocol) |
| **Data directory** | `/var/lib/postgresql/data` (`PGDATA` is set to this in the image) |
| **Init script** | [`dump.sql`](dump.sql) → `/docker-entrypoint-initdb.d/001_init.sql` |
| **Health** | `pg_isready -U <user> -d <db>` |
| **State** | Yes — needs a persistent volume |
| **Called by** | `product-catalog-service` (read-only `SELECT`s) |
| **Image size** | ~161 MB |

## What's inside

[`Dockerfile`](Dockerfile):

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

## Configuration

Standard `postgres` image variables. They are only read **on first initialisation** of an empty data directory.

| Variable | Used value | Description |
|---|---|---|
| `POSTGRES_DB` | `productcatalog` | database created on first start — **must match** the DB name in `product-catalog-service`'s `DATABASE_URL` |
| `POSTGRES_USER` | `catalog` | superuser created on first start |
| `POSTGRES_PASSWORD` | `catalog` (demo value) | superuser password — **put in a Kubernetes `Secret`** |
| `PGDATA` | `/var/lib/postgresql/data` (preset) | data directory |

If `POSTGRES_PASSWORD` is missing, the container refuses to start.

> **Important — init scripts run once.** Everything in `/docker-entrypoint-initdb.d/` only executes when the data directory is empty. If a volume already contains a database, changes to `dump.sql` (new image tag) are **ignored**. To re-seed, delete the volume/PVC (dev) or apply the change as a SQL migration.

## Kubernetes deployment notes

**Workload:** single-replica `StatefulSet` with a `volumeClaimTemplate` (this is not a clustered/HA setup; do not set `replicas > 1`).

**Ports:** `5432` (`postgres`). Headless or ClusterIP `Service` named `product-catalog-db`; the service connects to `product-catalog-db:5432` (use the FQDN `product-catalog-db.<namespace>.svc.cluster.local` across namespaces). Restrict access with a NetworkPolicy to `product-catalog-service` (and a metrics exporter, if added).

**Storage**

```yaml
volumeClaimTemplates:
  - metadata: { name: data }
    spec:
      accessModes: ["ReadWriteOnce"]
      resources: { requests: { storage: 2Gi } }   # 9 rows — 1Gi is ample
volumeMounts:
  - { name: data, mountPath: /var/lib/postgresql/data }
```

On volumes that contain a `lost+found` directory at the root (common with some provisioners), Postgres refuses to initialise ("directory exists but is not empty"). Either set `PGDATA=/var/lib/postgresql/data/pgdata` and keep the mount path, or mount a `subPath`.

**Probes**

```yaml
readinessProbe:
  exec: { command: ["sh", "-c", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"] }
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 10
livenessProbe:
  exec: { command: ["sh", "-c", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"] }
  initialDelaySeconds: 30
  periodSeconds: 10
```

`pg_isready` lives in the image. Using the env vars (rather than hard-coded names) keeps probes in sync with the Secret. First start takes a few seconds longer because the init script runs.

**Security context**

The image can run as the `postgres` user directly (UID/GID `999`, verified on the built image):

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 999
  runAsGroup: 999
  fsGroup: 999            # so the PVC is writable by postgres
  allowPrivilegeEscalation: false
  capabilities: { drop: ["ALL"] }
```

When started as non-root the entrypoint skips `gosu`/`chown`; the volume must already be writable by that UID (hence `fsGroup`). `readOnlyRootFilesystem: true` works with `emptyDir` mounts at `/var/run/postgresql` and `/tmp` (verified).

**Resources — untested starting point**

```yaml
resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits:   { memory: 512Mi }
```

**Config / secrets**

- A `Secret` (e.g. `product-catalog-db-credentials`) with keys `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, consumed via `envFrom.secretRef`. A matching `DATABASE_URL` for the service needs the same values.
- Create the Secret **before** the StatefulSet, and never commit the real password to the chart's `values.yaml`.

**Observability:** Postgres exposes no metrics natively (add a `postgres-exporter` sidecar if you want DB metrics). It cannot speak OTLP either, so its stdout logs must be collected by the platform (Alloy `loki.source.docker` in compose, `loki.source.kubernetes` in the cluster, selecting pods labelled `app.kubernetes.io/component=database`). The chart sets that label.

**Helm chart:** [`platform-demo-helm/product-catalog-db`](https://github.com/platform-boutique/platform-demo-helm/tree/main/product-catalog-db) — single-replica `StatefulSet` (headless + ClusterIP Services), PVC via `volumeClaimTemplates`
(retained on uninstall/scale-down), `PGDATA=/var/lib/postgresql/data/pgdata` (avoids the `lost+found` problem), non-root `999:999` with `fsGroup`, read-only root filesystem
(`emptyDir` at `/tmp` and `/var/run/postgresql`), `pg_isready` startup/readiness/liveness probes, NetworkPolicy allowing only `product-catalog-service`.
Credentials: set `auth.existingSecret` (keys `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`) or `auth.password`; the install fails if neither is provided.
Verified on a 3-node kind cluster under the `restricted` Pod Security Standard (read-only root, seed data loaded, `product-catalog-service` reading it).

**Deployment:** temporary, local-testing image (no release pipeline; on AWS the database is RDS and this chart is deleted). Argo CD deploys the chart from `platform-demo-helm`. Kyverno admits this unsigned image only under the label `app.kubernetes.io/name: product-catalog-db` with exactly this repository pinned by digest (a documented PolicyException, `platform-demo-helm/policies`).

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

## Known limitations

- Credentials in the compose/chart defaults are `catalog`/`catalog` — demo values only.
- Tagged `latest`; pin it for reproducible environments.
- Single instance, no replication or backups.
- The seed script is not a migration tool; schema changes against an existing volume need manual SQL.
