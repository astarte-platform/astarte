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

defmodule Astarte.Pairing.CertVerifierTest do
  use ExUnit.Case, async: true

  alias Astarte.Helpers.Database
  alias Astarte.Pairing.CertVerifier
  alias Astarte.Pairing.Config
  alias CFXXL.Client
  alias CFXXL.DName

  setup_all do
    cfxxl_client =
      Config.cfssl_url!()
      |> Client.new()

    {:ok, %{"certificate" => ca_crt}} = CFXXL.info(cfxxl_client, "")

    {:ok, cfxxl_client: cfxxl_client, ca_crt: ca_crt}
  end

  test "valid certificate", %{cfxxl_client: cfxxl_client, ca_crt: ca_crt} do
    hw_id = Database.random_128_bit_hw_id()

    {:ok, %{"certificate" => valid_cert}} =
      CFXXL.newcert(cfxxl_client, [], %DName{O: "Hemera"}, CN: "test/#{hw_id}", profile: "device")

    assert {:ok, %{timestamp: timestamp, until: until}} = CertVerifier.verify(valid_cert, ca_crt)

    my_now = Database.now_millis()

    assert_in_delta timestamp, my_now, 5000

    {:ok, %{"not_after" => not_after}} = CFXXL.certinfo(cfxxl_client, certificate: valid_cert)
    {:ok, not_after_datetime, 0} = DateTime.from_iso8601(not_after)
    not_after_unix = DateTime.to_unix(not_after_datetime, :millisecond)

    assert until == not_after_unix
  end

  test "expired certificate", %{cfxxl_client: cfxxl_client, ca_crt: ca_crt} do
    hw_id = Database.random_128_bit_hw_id()

    {:ok, %{"certificate" => valid_cert}} =
      CFXXL.newcert(
        cfxxl_client,
        [],
        %DName{O: "Hemera"},
        CN: "test/#{hw_id}",
        profile: "test-short-expiry"
      )

    # Simulate time after
    future_time = DateTime.add(DateTime.utc_now(), 2, :second)
    Mimic.expect(DateTime, :utc_now, fn -> future_time end)

    assert {:ok, %{valid: false, reason: :cert_expired}} = CertVerifier.verify(valid_cert, ca_crt)
  end
end
