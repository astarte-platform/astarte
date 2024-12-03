-- Copyright 2019 SECO Mind Srl
--
-- SPDX-License-Identifier: Apache-2.0

CREATE TABLE grouped_devices (
  group_name varchar,
  insertion_uuid timeuuid,
  device_id uuid,
  PRIMARY KEY ((group_name), insertion_uuid, device_id)
);
