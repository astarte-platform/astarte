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

defmodule Astarte.FDO.Config.BaseURLHost do
  @moduledoc """
  Custom Skogsra type for the FDO base URL host.

  The configured value is parsed once here and resolved to a `%BaseURLHost{}`
  struct that carries its `type`:

    * `:ip` (`value` is an `:inet.ip_address()`) when the value parses as an IP address
    * `:domain` (`value` is a `String.t()`) otherwise

  """

  use TypedStruct
  alias Astarte.FDO.Config.BaseURLHost

  defstruct [:type, :value]

  @behaviour Skogsra.Type

  @type t ::
          %__MODULE__{type: :domain, value: String.t()}
          | %__MODULE__{type: :ip, value: :inet.ip_address()}

  @impl Skogsra.Type
  def cast(value) when is_binary(value) and value != "" do
    case value |> String.to_charlist() |> :inet.parse_address() do
      {:ok, address} -> {:ok, %BaseURLHost{type: :ip, value: address}}
      {:error, _reason} -> {:ok, %BaseURLHost{type: :domain, value: value}}
    end
  end

  def cast({:domain, domain}) when is_binary(domain) and domain != "",
    do: {:ok, %BaseURLHost{type: :domain, value: domain}}

  def cast({:ip, address}) when is_tuple(address),
    do: {:ok, %BaseURLHost{type: :ip, value: address}}

  def cast(%BaseURLHost{} = base_url_host), do: {:ok, base_url_host}

  def cast(_), do: :error

  defimpl String.Chars do
    def to_string(%BaseURLHost{type: :domain, value: domain}), do: domain

    def to_string(%BaseURLHost{type: :ip, value: address}),
      do: address |> :inet.ntoa() |> List.to_string()
  end
end
