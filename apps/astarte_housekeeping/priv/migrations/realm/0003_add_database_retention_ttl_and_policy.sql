-- Copyright 2019-2020 SECO Mind Srl
--
-- SPDX-License-Identifier: Apache-2.0

ALTER TABLE endpoints
ADD (
  database_retention_ttl int,
  database_retention_policy int
);
