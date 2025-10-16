ALTER TABLE :keyspace.deletion_in_progress
ADD (
  groups set<text>
);
