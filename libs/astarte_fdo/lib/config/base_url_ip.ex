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

defmodule Astarte.FDO.Config.BaseURLIp do
  @moduledoc """
  Custom Skogsra type for the base URL IP address, used as an alternative
  (or addition) to `base_url_domain` for FDO URL composition.
  """

  use Skogsra.Type

  @impl Skogsra.Type
  def cast(value) when is_binary(value) do
    case value |> String.to_charlist() |> :inet.parse_address() do
      {:ok, address} -> {:ok, address |> :inet.ntoa() |> List.to_string()}
      {:error, _reason} -> :error
    end
  end

  @impl Skogsra.Type
  def cast(_value), do: :error
end
