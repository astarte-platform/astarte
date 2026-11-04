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

defmodule Astarte.PairingWeb.GraphQL.Resolvers.DeviceResolverTest do
  use Astarte.Pairing.Cases.Data, async: true
  use Astarte.Pairing.Cases.Device

  import Astarte.Pairing.Helpers.Device

  alias Astarte.PairingWeb.GraphQL.Resolvers.DeviceResolver

  @unauthorized {:error, "Unauthorized: Missing realm or device secret in context"}
  @no_context %{context: %{}}

  setup_all %{realm_name: realm_name, confirmed_device: device} do
    resolution = %{
      context: %{
        realm_name: realm_name,
        auth_token: device.credentials_secret,
        remote_ip: "127.0.0.1"
      }
    }

    %{resolution: resolution, hw_id: device.encoded_id}
  end

  describe "get_device/3" do
    test "returns the device's status and protocols", %{resolution: resolution, hw_id: hw_id} do
      assert {:ok, %{hw_id: ^hw_id, info: info}} =
               DeviceResolver.get_device(nil, %{hw_id: hw_id}, resolution)

      assert %{version: _, status: _, protocols: %{astarte_mqtt_v1: %{broker_url: _}}} = info
    end

    test "returns an error for the wrong secret", %{resolution: resolution, hw_id: hw_id} do
      resolution = put_in(resolution.context.auth_token, "wrongsecret")

      assert DeviceResolver.get_device(nil, %{hw_id: hw_id}, resolution) == {:error, :forbidden}
    end

    test "requires the realm and the secret in the context", %{hw_id: hw_id} do
      assert DeviceResolver.get_device(nil, %{hw_id: hw_id}, @no_context) == @unauthorized
    end
  end

  describe "obtain_credentials/3" do
    test "returns a client certificate for a valid CSR", %{resolution: resolution, hw_id: hw_id} do
      args = %{hw_id: hw_id, csr: csr()}

      assert {:ok, %{client_crt: client_crt}} =
               DeviceResolver.obtain_credentials(nil, args, resolution)

      assert client_crt =~ "-----BEGIN CERTIFICATE-----"
    end

    test "returns the validation error for an empty CSR", %{resolution: resolution, hw_id: hw_id} do
      args = %{hw_id: hw_id, csr: ""}

      assert {:error, %Ecto.Changeset{}} =
               DeviceResolver.obtain_credentials(nil, args, resolution)
    end

    test "requires the realm and the secret in the context", %{hw_id: hw_id} do
      args = %{hw_id: hw_id, csr: csr()}

      assert DeviceResolver.obtain_credentials(nil, args, @no_context) == @unauthorized
    end
  end

  describe "verify_credentials/3" do
    test "reports a certificate issued to the device as valid", ctx do
      %{resolution: resolution, hw_id: hw_id} = ctx

      {:ok, %{client_crt: client_crt}} =
        DeviceResolver.obtain_credentials(nil, %{hw_id: hw_id, csr: csr()}, resolution)

      args = %{hw_id: hw_id, client_crt: client_crt}

      assert {:ok, %{valid: true, cause: nil, timestamp: timestamp, until: until}} =
               DeviceResolver.verify_credentials(nil, args, resolution)

      assert is_integer(timestamp)
      assert is_integer(until)
    end

    test "reports why a certificate is invalid", %{resolution: resolution, hw_id: hw_id} do
      args = %{hw_id: hw_id, client_crt: "invalid crt"}

      assert {:ok, %{valid: false, cause: "INVALID"}} =
               DeviceResolver.verify_credentials(nil, args, resolution)
    end

    test "returns the validation error for an empty certificate", ctx do
      args = %{hw_id: ctx.hw_id, client_crt: ""}

      assert {:error, %Ecto.Changeset{}} =
               DeviceResolver.verify_credentials(nil, args, ctx.resolution)
    end

    test "requires the realm and the secret in the context", %{hw_id: hw_id} do
      args = %{hw_id: hw_id, client_crt: "invalid crt"}

      assert DeviceResolver.verify_credentials(nil, args, @no_context) == @unauthorized
    end
  end
end
