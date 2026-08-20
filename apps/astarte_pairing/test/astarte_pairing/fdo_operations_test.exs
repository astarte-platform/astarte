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
  alias Astarte.Pairing.Engine
  alias Astarte.Pairing.FDOOperations

  @realm "testrealm"
  @expiry ~U[2026-01-01 00:00:00Z]

  @valid_req %LoadRequest{
    hw_id: "hw-id",
    initial_introspection: %{},
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

  test "returns the public key and guid when validation, claim, store and registration succeed" do
    stub_changeset(Ecto.Changeset.change(@valid_req))
    expect(OwnershipVoucher, :claim_on_rendezvous, fn _guid, _voucher, _key -> {:ok, @expiry} end)
    expect(LoadRequest, :store_voucher, fn _req, @expiry -> :ok end)
    expect(Engine, :register_device, fn @realm, _hw_id, _opts -> {:ok, nil} end)

    assert FDOOperations.register_ownership_voucher(%{}, @realm) ==
             {:ok, %{public_key: @valid_req.extracted_owner_key.public_pem, guid: "device-guid"}}
  end

  test "passes the request fields through to the claim and the registration" do
    stub_changeset(Ecto.Changeset.change(@valid_req))

    expect(OwnershipVoucher, :claim_on_rendezvous, fn guid, voucher, key ->
      assert guid == @valid_req.device_guid
      assert voucher == @valid_req.decoded_ownership_voucher
      assert key == @valid_req.extracted_owner_key

      {:ok, @expiry}
    end)

    expect(LoadRequest, :store_voucher, fn _req, @expiry -> :ok end)

    expect(Engine, :register_device, fn @realm, hw_id, opts ->
      assert hw_id == @valid_req.hw_id
      assert Keyword.fetch!(opts, :initial_introspection) == @valid_req.initial_introspection
      assert Keyword.fetch!(opts, :with_credentials?) == false
      assert Keyword.fetch!(opts, :fdo_guid) == @valid_req.device_guid

      {:ok, nil}
    end)

    assert {:ok, _} = FDOOperations.register_ownership_voucher(%{}, @realm)
  end

  test "returns the changeset error and never claims when validation fails" do
    invalid = Ecto.Changeset.add_error(Ecto.Changeset.change(@valid_req), :key_name, "is invalid")
    stub_changeset(invalid)

    reject(&OwnershipVoucher.claim_on_rendezvous/3)
    reject(&LoadRequest.store_voucher/2)
    reject(&Engine.register_device/3)

    assert {:error, %Ecto.Changeset{valid?: false}} =
             FDOOperations.register_ownership_voucher(%{}, @realm)
  end

  test "returns the error and never stores when the claim fails" do
    stub_changeset(Ecto.Changeset.change(@valid_req))

    expect(OwnershipVoucher, :claim_on_rendezvous, fn _guid, _voucher, _key ->
      {:error, :timeout}
    end)

    reject(&LoadRequest.store_voucher/2)
    reject(&Engine.register_device/3)

    assert FDOOperations.register_ownership_voucher(%{}, @realm) == {:error, :timeout}
  end

  test "returns the error and logs the claimed voucher when storing it fails" do
    stub_changeset(Ecto.Changeset.change(@valid_req))
    expect(OwnershipVoucher, :claim_on_rendezvous, fn _guid, _voucher, _key -> {:ok, @expiry} end)
    expect(LoadRequest, :store_voucher, fn _req, @expiry -> {:error, :connection_error} end)

    reject(&Engine.register_device/3)

    log =
      capture_log(fn ->
        assert FDOOperations.register_ownership_voucher(%{}, @realm) ==
                 {:error, :connection_error}
      end)

    assert log =~ "the voucher could not be persisted"
    assert log =~ @realm
    assert log =~ @valid_req.device_guid
  end

  test "returns the error and logs the claimed voucher when the device registration fails" do
    stub_changeset(Ecto.Changeset.change(@valid_req))
    expect(OwnershipVoucher, :claim_on_rendezvous, fn _guid, _voucher, _key -> {:ok, @expiry} end)
    expect(LoadRequest, :store_voucher, fn _req, @expiry -> :ok end)
    expect(Engine, :register_device, fn @realm, _hw_id, _opts -> {:error, :realm_not_found} end)

    log =
      capture_log(fn ->
        assert FDOOperations.register_ownership_voucher(%{}, @realm) ==
                 {:error, :realm_not_found}
      end)

    assert log =~ "the device could not be registered"
    assert log =~ @realm
    assert log =~ @valid_req.device_guid
  end
end
