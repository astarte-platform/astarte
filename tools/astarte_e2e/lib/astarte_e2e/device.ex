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
  use Supervisor

  require Logger

  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Interface
  alias AstarteE2E.Client
  alias AstarteE2E.Config

  def start_link(opts) do
    realm_result = Keyword.fetch(opts, :realm)
    device_id_result = Keyword.fetch(opts, :device_id)

    case {realm_result, device_id_result} do
      {{:ok, realm}, {:ok, device_id}} ->
        Supervisor.start_link(__MODULE__, opts, name: device_name(realm, device_id))

      _ ->
        Logger.warning("Trying to start a device without realm or device_id")
        {:error, :invalid_args}
    end
  end

  @impl Supervisor
  def init(opts) do
    realm = Keyword.fetch!(opts, :realm)
    device_id = Keyword.fetch!(opts, :device_id)
    interface_maps = Keyword.get(opts, :interfaces, [])

    interfaces =
      for interface_params <- interface_maps do
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

    # TODO: interfaces should not be needed, as they could be inferred from device.introspection
    #   unfortunately, the device generator does not fill out the introspection field as of now
    credentials_secret = register_device!(realm, device, interfaces)

    interface_provider =
      {Astarte.Device.SimpleInterfaceProvider, interfaces: interface_maps}

    device_opts =
      Config.device_opts()
      |> Keyword.put(:interface_provider, interface_provider)
      |> Keyword.put(:credentials_secret, credentials_secret)
      |> Keyword.put(:device_id, device.encoded_id)

    client_opts =
      Config.client_opts()
      |> Keyword.put(:device_id, device.encoded_id)

    [
      {Astarte.Device, device_opts},
      {Client, client_opts}
    ]
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp register_device!(realm, device, interfaces) do
    astarte_pairing_url = Config.pairing_url!()
    astarte_jwt = Config.jwt!()

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

  defp device_name(realm, device_id),
    do: {:via, Registry, {Registry.AstarteE2E, {:device, realm, device_id}}}
end
