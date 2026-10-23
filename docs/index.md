# product-catalog-db

<div class="pd-hero" markdown>
<span class="pd-kicker">database · platform-demo</span>

> **Temporary.** This image is hand-built, has no pipeline and no signature. Its `StatefulSet` stays in the cluster for now: the shop is going to move to another cluster later, so it is not replaced by Amazon RDS (the only RDS database is the one behind Backstage). Until then the Helm chart, the allow-list entry in the Helm CI and the Kyverno PolicyException stay.
</div>

<div class="pd-facts" markdown>
<div><span>Runtime</span><strong>PostgreSQL 17</strong><small>SQL</small></div>
<div><span>Listens on</span><strong>5432</strong><small>SQL</small></div>
<div><span>State</span><strong>Stateful</strong></div>
<div><span>Image</span><strong>product-catalog-db</strong><small>mladenovskistefan/</small></div>
</div>

## Where it sits

Called by `product-catalog-service`. It has no downstream dependencies.

```mermaid
flowchart LR
  product_catalog_db["<b>product-catalog-db</b><br/>5432 (SQL)"]:::me
  product_catalog_service["product-catalog-service"] --> product_catalog_db
  classDef me stroke-width:3px;
```

## At a glance

| | |
|---|---|
| **Engine** | PostgreSQL 17 (`postgres:17`, currently 17.9 on Debian) |
| **Image** | `mladenovskistefan/product-catalog-db` (tag `latest`; consider pinning) |
| **Port** | `5432` (PostgreSQL wire protocol) |
| **Data directory** | `/var/lib/postgresql/data` (`PGDATA` is set to this in the image) |
| **Init script** | [`dump.sql`](https://github.com/platform-boutique/app-product-catalog-db/blob/main/dump.sql) → `/docker-entrypoint-initdb.d/001_init.sql` |
| **Health** | `pg_isready -U <user> -d <db>` |
| **State** | Yes — needs a persistent volume |
| **Called by** | `product-catalog-service` (read-only `SELECT`s) |
| **Image size** | ~161 MB |

## Find it elsewhere

<div class="pd-cards" markdown>
<div><h4><a href="https://argocd.platform-demo.click/applications/argocd/dev-product-catalog-db">Argo CD</a></h4><p>Sync and health of <code>dev-product-catalog-db</code>.</p></div>

<div><h4><a href="https://github.com/platform-boutique/app-product-catalog-db">Repository</a></h4><p>Source, pull requests and releases of <code>app-product-catalog-db</code>.</p></div>
</div>

!!! info "Part of the platform-demo platform"
    Cross-cutting facts (service wiring, observability contract, Kubernetes translation, CI/CD) are in the
    [master reference](https://github.com/platform-boutique/platform-demo-docs). This site only describes product-catalog-db.
