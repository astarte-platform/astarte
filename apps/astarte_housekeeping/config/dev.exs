# Copyright 2017-2023 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

import Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:realm, :datacenter, :replication_factor, :module, :function, :tag]
