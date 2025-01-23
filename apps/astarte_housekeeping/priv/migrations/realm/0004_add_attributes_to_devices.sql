-- Copyright 2021 SECO Mind Srl
--
-- SPDX-License-Identifier: Apache-2.0

ALTER TABLE devices
ADD (
    attributes map<varchar, varchar>
);
