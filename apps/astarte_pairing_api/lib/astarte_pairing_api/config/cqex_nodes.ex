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

defmodule Astarte.Pairing.API.Config.CQExNodes do
  use Skogsra.Type

  @default_port 9042

  @impl Skogsra.Type
  @spec cast(String.t()) :: {:ok, [{String.t(), integer()}]} | :error
  def cast(value)

  def cast(""), do: :error

  def cast(value) when is_binary(value) do
    nodes =
      value
      |> String.split(",", trim: true)
      |> Enum.reduce_while([], fn host_port_str, acc ->
        trimmed_str = String.trim(host_port_str)

        with [host, port_str] <- String.split(trimmed_str, ":", parts: 2),
             {port, ""} <- Integer.parse(port_str) do
          {:cont, [{host, port} | acc]}
        else
          [host] ->
            {:cont, [{host, @default_port} | acc]}

          _ ->
            {:halt, :error}
        end
      end)

    case nodes do
      :error ->
        :error

      _ ->
        {:ok, nodes}
    end
  end

  def cast(_) do
    :error
  end
end
