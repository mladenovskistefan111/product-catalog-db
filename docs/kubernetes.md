# Kubernetes

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
Verified in the earlier local phase on a 3-node kind cluster (since deleted) under the `restricted` Pod Security Standard (read-only root, seed data loaded, `product-catalog-service` reading it); not verified on EKS yet.

**Deployment:** temporary, hand-built image (no release pipeline); the `StatefulSet` stays in the cluster for now because the shop moves to another cluster later (it is not replaced by RDS). Argo CD deploys the chart from `platform-demo-helm`. Kyverno admits this unsigned image only under the label `app.kubernetes.io/name: product-catalog-db` with exactly this repository pinned by digest (a documented PolicyException, `platform-demo-helm/policies`).
