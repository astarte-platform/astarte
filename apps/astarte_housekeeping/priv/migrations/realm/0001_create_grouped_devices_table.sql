CREATE TABLE grouped_devices (
  group_name varchar,
  insertion_uuid timeuuid,
  device_id uuid,
  PRIMARY KEY ((group_name), insertion_uuid, device_id)
);
