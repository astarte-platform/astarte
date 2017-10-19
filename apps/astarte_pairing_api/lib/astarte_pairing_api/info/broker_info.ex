defmodule Astarte.Pairing.API.Info.BrokerInfo do
  @enforce_keys [:url, :version]
  defstruct [:url, :version]
end
