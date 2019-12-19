defmodule Astarte.RealmManagement.API.DataCase do
  use ExUnit.CaseTemplate

  setup_all do
    Astarte.RealmManagement.Mock.DB.start_link()
    :ok
  end

  setup do
    on_exit(fn ->
      Astarte.RealmManagement.Mock.DB.drop_interfaces()
    end)
  end
end
