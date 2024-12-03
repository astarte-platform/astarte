-- Copyright 2019 SECO Mind Srl
--
-- SPDX-License-Identifier: Apache-2.0

ALTER TABLE devices
ADD (
  groups map<text, timeuuid>,
  exchanged_bytes_by_interface map<frozen<tuple<ascii, int>>, bigint>,
  exchanged_msgs_by_interface map<frozen<tuple<ascii, int>>, bigint>
);
