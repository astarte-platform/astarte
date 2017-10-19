defmodule Astarte.Pairing.APIWeb.BrokerInfoControllerTest do
  use Astarte.Pairing.APIWeb.ConnCase

  alias Astarte.Pairing.Mock

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "get info" do
    test "returns the correct info", %{conn: conn} do
      conn = get conn, broker_info_path(conn, :show)
      assert json_response(conn, 200) == %{"url" => Mock.broker_url(), "version" => Mock.version()}
    end
  end
end
