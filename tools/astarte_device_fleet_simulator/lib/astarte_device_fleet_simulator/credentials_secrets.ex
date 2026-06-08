#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule AstarteDeviceFleetSimulator.CredentialsSecrets do
  alias AstarteDeviceFleetSimulator.Config
  require Logger

  @separator ?;

  @doc """
  Return the stored device credential secrets, in a map %{device_id => credentials_secret}
  """
  @spec fetch() :: %{String.t() => String.t()}
  def fetch() do
    case File.exists?(Config.credentials_secrets_location!()) do
      true -> fetch!()
      false -> %{}
    end
  end

  @spec fetch!() :: %{String.t() => String.t()}
  defp fetch!() do
    Config.credentials_secrets_location!()
    |> File.stream!()
    |> CSV.decode!(separator: @separator)
    |> Stream.filter(fn [pairing_url, realm, _device_id, _credentials_secret] ->
      pairing_url == Config.pairing_url!() and realm == Config.realm!()
    end)
    |> Map.new(fn [_pairing_url, _realm, device_id, credentials_secret] ->
      {device_id, credentials_secret}
    end)
  end

  @doc """
  Store the given device in the cached credential secrets.
  """
  @spec store(String.t(), String.t()) :: :ok
  def store(device_id, credentials_secret) do
    pairing_url = Config.pairing_url!()
    realm = Config.realm!()

    [line] =
      [[pairing_url, realm, device_id, credentials_secret]]
      |> CSV.encode(separator: @separator, delimiter: "\n")
      |> Enum.to_list()

    Config.credentials_secrets_location!()
    |> File.open([:append])
    |> case do
      {:ok, file} ->
        IO.write(file, line)
        File.close(file)

        :ok

      {:error, error} ->
        Logger.warning("Error opening credentials store file: #{inspect(error)}")
    end
  end
end
