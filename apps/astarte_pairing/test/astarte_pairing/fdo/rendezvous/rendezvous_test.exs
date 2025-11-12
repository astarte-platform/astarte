#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.FDO.RendezvousTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Pairing.FDO.Rendezvous
  alias Astarte.Pairing.FDO.Rendezvous.Client

  import Astarte.Helpers.FDO

  setup :verify_on_exit!

  describe "send_hello/0" do
    test "returns {:ok, body} on 200 response" do
      nonce = nonce() |> Enum.at(0)

      Client
      |> expect(:post, fn "/fdo/101/msg/20", _body, _headers ->
        {:ok,
         %HTTPoison.Response{status_code: 200, headers: "some_headers", body: hello_ack(nonce)}}
      end)

      assert {:ok, %{nonce: nonce, headers: "some_headers"}} == Rendezvous.send_hello()
    end

    test "returns :error on non-200 response" do
      Client
      |> expect(:post, fn _, _, _ ->
        {:ok, %HTTPoison.Response{status_code: 500, body: "bad"}}
      end)

      assert :error = Rendezvous.send_hello()
    end

    test "returns :error on HTTP error" do
      Client
      |> expect(:post, fn _, _, _ -> {:error, :timeout} end)

      assert :error = Rendezvous.send_hello()
    end
  end

  describe "register_ownership/2" do
    test "returns {:ok, body} on 200 response" do
      request_body = "payload"
      headers = [{"authorization", "Bearer token"}]

      Client
      |> expect(:post, fn "/fdo/101/msg/22", "payload", headers_with_auth ->
        assert {"Authorization", "Bearer token"} in headers_with_auth
        {:ok, %HTTPoison.Response{status_code: 200, body: "some_cbor_response"}}
      end)

      assert :ok = Rendezvous.register_ownership(request_body, headers)
    end

    test "returns :error on http error" do
      Client
      |> expect(:post, fn _, _, _ -> {:error, :connection_refused} end)

      assert :error =
               Rendezvous.register_ownership("payload", [{"authorization", "Bearer token"}])
    end
  end
end
