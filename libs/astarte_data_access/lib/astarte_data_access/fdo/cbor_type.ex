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

defmodule Astarte.DataAccess.FDO.CBORType do
  @moduledoc """
  A generic Ecto parameterized type that stores values as CBOR binaries.

  The `using:` option must be set to a module that implements:
    - `encode_cbor/1` – encodes a value to a CBOR binary
    - `decode_cbor/1` – decodes a CBOR binary, returning `{:ok, value} | {:error, reason}`

  ## Example

      field :replacement_rv_info, Astarte.DataAccess.FDO.CBORType,
        using: Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo
  """

  use Ecto.ParameterizedType

  @impl Ecto.ParameterizedType
  def init(opts) do
    module = Keyword.fetch!(opts, :using)
    %{module: module}
  end

  @impl Ecto.ParameterizedType
  def type(_params), do: :binary

  @impl Ecto.ParameterizedType
  def load(nil, _loader, _params), do: {:ok, nil}

  def load(data, _loader, %{module: module}) when is_binary(data) do
    case module.decode_cbor(data) do
      {:ok, value} -> {:ok, value}
      _ -> :error
    end
  end

  def load(_, _, _), do: :error

  @impl Ecto.ParameterizedType
  def dump(nil, _dumper, _params), do: {:ok, nil}

  def dump(value, _dumper, %{module: module}) do
    {:ok, module.encode_cbor(value)}
  end

  def dump(_, _, _), do: :error

  @impl Ecto.ParameterizedType
  def cast(nil, _params), do: {:ok, nil}
  def cast(value, _params), do: {:ok, value}
end
