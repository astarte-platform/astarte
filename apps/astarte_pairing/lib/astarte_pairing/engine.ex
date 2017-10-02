defmodule Astarte.Pairing.Engine do
  @moduledoc """
  This module performs the pairing operations requested via RPC.
  """

  alias Astarte.Pairing.Config

  @version Mix.Project.config[:version]

  def get_info do
    %{version: @version,
      url: Config.broker_url!()}
  end
end
