ALTER TABLE endpoints
ADD (
  database_retention_ttl int,
  database_retention_policy int
);
