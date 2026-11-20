defmodule Astarte.RealmManagementWeb.GraphQL.SchemaTest do
  use ExUnit.Case, async: true

  alias Astarte.RealmManagementWeb.GraphQL.Middleware.HandleErrors
  alias Astarte.RealmManagementWeb.GraphQL.Schema

  describe "middleware/3" do
    test "appends HandleErrors to queries" do
      middleware = [:some_middleware]
      result = Schema.middleware(middleware, %{}, %{identifier: :query})
      assert result == middleware ++ [HandleErrors]
    end

    test "appends HandleErrors to mutations" do
      middleware = [:some_middleware]
      result = Schema.middleware(middleware, %{}, %{identifier: :mutation})
      assert result == middleware ++ [HandleErrors]
    end

    test "does not append HandleErrors to other fields" do
      middleware = [:some_middleware]
      result = Schema.middleware(middleware, %{}, %{identifier: :subscription})
      assert result == middleware
    end
  end
end
