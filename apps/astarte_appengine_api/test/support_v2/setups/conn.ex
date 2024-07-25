defmodule Astarte.Test.Setups.Conn do
  import Plug.Conn
  alias Phoenix.ConnTest
  alias Astarte.Test.Helpers.JWT, as: JWTHelper

  def create_conn(_context) do
    {:ok, conn: ConnTest.build_conn()}
  end

  def jwt(_context) do
    {:ok, jwt: JWTHelper.gen_jwt_all_access_token()}
  end

  def auth_conn(%{conn: conn, jwt: {jwt, _claims}}) do
    auth_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "bearer #{jwt}")

    {:ok, auth_conn: auth_conn}
  end
end
