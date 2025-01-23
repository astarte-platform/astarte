-- Copyright 2023 SECO Mind Srl
--
-- SPDX-License-Identifier: Apache-2.0

CREATE TABLE deletion_in_progress (
  device_id uuid,
  vmq_ack boolean,
  dup_start_ack boolean,
  dup_end_ack boolean,
  PRIMARY KEY (device_id)
);
