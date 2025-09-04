#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E.Device do
  require Logger

  alias Astarte.Core.Device
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Interface
  alias AstarteE2E.Config

  def start_link(opts) do
    realm_result = Keyword.fetch(opts, :realm)
    device_id_result = Keyword.fetch(opts, :device_id)

    case {realm_result, device_id_result} do
      {{:ok, _realm}, {:ok, _device_id}} ->
        credentials_secret = register_device!(opts)
        opts = Keyword.put(opts, :credentials_secret, credentials_secret)
        device_opts = device_opts(opts)

        with {:ok, pid} <- Astarte.Device.start_link(device_opts) do
          Astarte.Device.wait_for_connection(pid)
          {:ok, pid}
        end

      _ ->
        Logger.warning("Trying to start a device without realm or device_id")
        {:error, :invalid_args}
    end
  end

  defp device_opts(opts) do
    device_id = Keyword.fetch!(opts, :device_id)
    credentials_secret = Keyword.fetch!(opts, :credentials_secret)
    interfaces = Keyword.get(opts, :interfaces, [])

    encoded_id = Device.encode_device_id(device_id)

    interface_provider =
      {Astarte.Device.SimpleInterfaceProvider, interfaces: interfaces}

    Config.device_opts()
    |> Keyword.put(:interface_provider, interface_provider)
    |> Keyword.put(:credentials_secret, credentials_secret)
    |> Keyword.put(:device_id, encoded_id)
  end

  defp register_device!(opts) do
    realm = Keyword.fetch!(opts, :realm)
    device_id = Keyword.fetch!(opts, :device_id)
    interfaces = Keyword.get(opts, :interfaces, [])
    astarte_pairing_url = Config.pairing_url!()
    astarte_jwt = Config.jwt!()

    interfaces =
      for interface_params <- interfaces do
        %Interface{}
        |> Interface.changeset(interface_params)
        |> Ecto.Changeset.apply_action!(:insert)
      end

    params =
      opts
      |> Keyword.delete(:device_id)
      |> Keyword.put(:id, device_id)
      |> Keyword.put(:interfaces, interfaces)

    device = DeviceGenerator.device(params) |> Enum.at(0)

    introspection =
      interfaces
      |> Map.new(
        &{&1.name,
         %{
           "major" => &1.major_version,
           "minor" => &1.minor_version
         }}
      )

    url = Path.join([astarte_pairing_url, "v1", realm, "agent/devices"])

    body =
      %{
        "data" => %{
          "hw_id" => device.encoded_id,
          "initial_introspection" => introspection
        }
      }
      |> Jason.encode!()

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{astarte_jwt}"}
    ]

    %HTTPoison.Response{status_code: 201, body: response} = HTTPoison.post!(url, body, headers)

    response
    |> Jason.decode!()
    |> get_in(["data", "credentials_secret"])
  end
end
