# Copyright 2017-2023 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

import Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [
    :realm,
    :interface,
    :interface_major,
    :trigger_name,
    :policy_name,
    :module,
    :function,
    :tag
  ]
