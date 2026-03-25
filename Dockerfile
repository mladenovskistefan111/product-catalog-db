FROM postgres:17

COPY dump.sql /docker-entrypoint-initdb.d/001_init.sql