# Copyright 2017-2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

defmodule Astarte.RealmManagement.APIWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common datastructures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  alias Astarte.RealmManagement.Mock

  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest
      import Astarte.RealmManagement.APIWeb.Router.Helpers

      # The default endpoint for testing
      @endpoint Astarte.RealmManagement.APIWeb.Endpoint
    end
  end

  setup _tags do
    on_exit(fn ->
      Mock.DB.drop_interfaces()
    end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  setup_all do
    Mock.DB.start_link()
    :ok
  end
end
