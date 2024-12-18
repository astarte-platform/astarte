# Copyright 2024 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

defmodule Astarte.Config do
  alias Astarte.DataAccess.Config, as: DataAccessConfig

  def xandra_options! do
    cluster = Application.get_env(:astarte_import, :cluster_name)
    # Dropping :autodiscovery since the option has been deprecated in xandra v0.15.0
    # and is now always enabled.
    DataAccessConfig.xandra_options!()
    |> Keyword.drop([:autodiscovery])
    |> Keyword.put(:name, cluster)
  end
end
