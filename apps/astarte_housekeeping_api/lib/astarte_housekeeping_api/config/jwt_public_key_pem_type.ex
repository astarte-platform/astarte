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

defmodule Astarte.Housekeeping.API.Config.JWTPublicKeyPEMType do
  use Skogsra.Type

  require Logger

  @impl Skogsra.Type
  @spec cast(String.t()) :: String.t() | :error
  def cast(value)

  def cast(value) when is_binary(value) do
    if String.starts_with?(value, "-----BEGIN PUBLIC KEY-----") do
      {:ok, value}
    else
      # assume the value to be the path in which the key is stored
      case File.read(value) do
        {:ok, key} ->
          {:ok, key}

        {:error, reason} ->
          Logger.warning("Error while reading file: #{inspect(reason)}.",
            tag: "file_error_jwt_key"
          )

          :error
      end
    end
  end

  def cast(_), do: :error
end
