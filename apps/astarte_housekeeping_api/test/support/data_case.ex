defmodule Astarte.Housekeeping.API.DataCase do
  use ExUnit.CaseTemplate

  setup_all do
    Astarte.Housekeeping.Mock.start_link()
    Astarte.Housekeeping.Mock.DB.start_link()
    :ok
  end
end
