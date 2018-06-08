defmodule Astarte.RealmManagement.API.DataCase do
  use ExUnit.CaseTemplate

  setup_all do
    Astarte.RealmManagement.Mock.DB.start_link()
    :ok
  end
end
