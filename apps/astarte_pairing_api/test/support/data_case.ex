defmodule Astarte.Pairing.API.DataCase do
  use ExUnit.CaseTemplate

  setup_all do
    Astarte.Pairing.Mock.start_link()
    :ok
  end
end

