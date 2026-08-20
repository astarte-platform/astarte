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

defmodule Astarte.Pairing.FDOOperationsTest do
  use ExUnit.Case
  use Mimic

  import ExUnit.CaptureLog

  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.FDO.TO0
  alias Astarte.Pairing.FDOOperations

  @realm "testrealm"

  @valid_req %LoadRequest{
    cbor_ownership_voucher: <<1, 2, 3>>,
    device_guid: "device-guid",
    key_name: "owner_key",
    key_algorithm: :es256,
    replacement_guid: nil,
    decoded_replacement_rendezvous_info: nil,
    decoded_replacement_public_key: nil,
    decoded_ownership_voucher: %{fake: :voucher},
    extracted_owner_key: %{public_pem: "-----BEGIN PUBLIC KEY-----fake-----END PUBLIC KEY-----"}
  }

  defp stub_changeset(result) do
    expect(LoadRequest, :changeset, fn %LoadRequest{}, _params -> result end)
  end

  test "returns the public key and guid when validation, save and claim all succeed" do
    stub_changeset(Ecto.Changeset.change(@valid_req))
    expect(OwnershipVoucher, :save_voucher, fn @realm, _attrs -> :ok end)
    expect(TO0, :claim_ownership_voucher, fn @realm, _voucher, _key -> :ok end)

    assert FDOOperations.register_ownership_voucher(%{}, @realm) ==
             {:ok, %{public_key: @valid_req.extracted_owner_key.public_pem, guid: "device-guid"}}
  end

  test "passes the request fields through to save_voucher" do
    stub_changeset(Ecto.Changeset.change(@valid_req))

    expect(OwnershipVoucher, :save_voucher, fn @realm, attrs ->
      assert attrs == %{
               voucher_data: @valid_req.cbor_ownership_voucher,
               guid: @valid_req.device_guid,
               key_name: @valid_req.key_name,
               key_algorithm: @valid_req.key_algorithm,
               replacement_guid: nil,
               replacement_rendezvous_info: nil,
               replacement_public_key: nil
             }

      :ok
    end)

    expect(TO0, :claim_ownership_voucher, fn @realm, _voucher, _key -> :ok end)

    assert {:ok, _} = FDOOperations.register_ownership_voucher(%{}, @realm)
  end

  test "returns the changeset error and never saves or claims when validation fails" do
    invalid = Ecto.Changeset.add_error(Ecto.Changeset.change(@valid_req), :key_name, "is invalid")
    stub_changeset(invalid)

    reject(&OwnershipVoucher.save_voucher/2)
    reject(&TO0.claim_ownership_voucher/3)

    assert {:error, %Ecto.Changeset{valid?: false}} =
             FDOOperations.register_ownership_voucher(%{}, @realm)
  end

  test "returns the error and never claims when saving the voucher fails" do
    stub_changeset(Ecto.Changeset.change(@valid_req))
    expect(OwnershipVoucher, :save_voucher, fn @realm, _attrs -> {:error, :connection_error} end)

    reject(&TO0.claim_ownership_voucher/3)

    assert FDOOperations.register_ownership_voucher(%{}, @realm) ==
             {:error, :connection_error}
  end

  test "returns the error and logs the orphaned voucher when the TO0 claim fails after saving" do
    stub_changeset(Ecto.Changeset.change(@valid_req))
    expect(OwnershipVoucher, :save_voucher, fn @realm, _attrs -> :ok end)
    expect(TO0, :claim_ownership_voucher, fn @realm, _voucher, _key -> {:error, :timeout} end)

    log =
      capture_log(fn ->
        assert FDOOperations.register_ownership_voucher(%{}, @realm) == {:error, :timeout}
      end)

    assert log =~ "TO0 ownership claim failed after the voucher was already persisted"
    assert log =~ @realm
    assert log =~ @valid_req.device_guid
  end
end
