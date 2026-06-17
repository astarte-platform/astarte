CREATE TABLE :keyspace.unconfirmed_devices (
  device_id uuid,
  created_at timestamp,
  PRIMARY KEY (device_id)
);
