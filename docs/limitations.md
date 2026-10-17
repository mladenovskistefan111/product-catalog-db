# Known limitations

- Credentials in the compose/chart defaults are `catalog`/`catalog` — demo values only.
- Tagged `latest`; pin it for reproducible environments.
- Single instance, no replication or backups.
- The seed script is not a migration tool; schema changes against an existing volume need manual SQL.
