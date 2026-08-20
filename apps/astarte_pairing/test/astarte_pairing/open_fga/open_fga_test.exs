#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Pairing.OpenFGATest do
  use ExUnit.Case
  use Mimic

  alias Astarte.Pairing.OpenFGA
  alias Astarte.Pairing.OpenFGA.Client

  # Matches the :openfga_store_id configured in config/test.exs.
  @store_id "test_store_id"

  defp respond(status, body) do
    fn _url, _body, _headers ->
      {:ok, %HTTPoison.Response{status_code: status, body: body}}
    end
  end

  test "returns :ok when OpenFGA allows the check" do
    expect(Client, :post, respond(200, Jason.encode!(%{"allowed" => true})))

    assert OpenFGA.check("user:1", "viewer", "realm:test") == :ok
  end

  test "returns {:error, :forbidden} when OpenFGA denies the check" do
    expect(Client, :post, respond(200, Jason.encode!(%{"allowed" => false})))

    assert OpenFGA.check("user:1", "viewer", "realm:test") == {:error, :forbidden}
  end

  test "sends the configured store id, and the user/relation/object tuple" do
    expect(Client, :post, fn url, body, headers ->
      assert url == "/stores/#{@store_id}/check"
      assert {"Content-Type", "application/json"} in headers

      assert Jason.decode!(body) == %{
               "tuple_key" => %{
                 "user" => "user:42",
                 "relation" => "can_unregister",
                 "object" => "device:abc123"
               }
             }

      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"allowed" => true})}}
    end)

    assert OpenFGA.check("user:42", "can_unregister", "device:abc123") == :ok
  end

  test "returns {:error, :unexpected_response} when the body has no \"allowed\" key" do
    expect(Client, :post, respond(200, Jason.encode!(%{"unexpected" => "shape"})))

    assert OpenFGA.check("user:1", "viewer", "realm:test") == {:error, :unexpected_response}
  end

  test "returns {:error, :unexpected_response} when the 200 body isn't valid JSON" do
    expect(Client, :post, respond(200, "not json"))

    assert OpenFGA.check("user:1", "viewer", "realm:test") == {:error, :unexpected_response}
  end

  test "returns {:error, {:unexpected_status, status}} on a non-200 response, not :forbidden" do
    expect(Client, :post, respond(500, "internal error"))

    assert OpenFGA.check("user:1", "viewer", "realm:test") == {:error, {:unexpected_status, 500}}
  end

  test "returns {:error, reason} when the request itself fails" do
    expect(Client, :post, fn _url, _body, _headers ->
      {:error, %HTTPoison.Error{reason: :nxdomain}}
    end)

    assert OpenFGA.check("user:1", "viewer", "realm:test") == {:error, :nxdomain}
  end
end
