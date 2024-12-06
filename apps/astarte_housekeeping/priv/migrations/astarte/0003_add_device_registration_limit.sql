-- Copyright 2023 SECO Mind Srl
--
-- SPDX-License-Identifier: Apache-2.0

ALTER TABLE realms
ADD (
  device_registration_limit bigint
);
