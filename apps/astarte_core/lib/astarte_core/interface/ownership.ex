#
# This file is part of Astarte.
#
# Copyright 2017-2024 SECO Mind Srl
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

defmodule Astarte.Core.Interface.Ownership do
  @moduledoc """
  Ecto type for Astarte interface ownership (device or server).
  """

  use Ecto.Type

  @type t :: :device | :server

  @interface_ownership_device 1
  @interface_ownership_server 2
  @valid_atoms [
    :device,
    :server
  ]

  @impl true
  def type, do: :integer

  @impl true
  def cast(nil), do: {:ok, nil}

  def cast(atom) when is_atom(atom) do
    if Enum.member?(@valid_atoms, atom) do
      {:ok, atom}
    else
      :error
    end
  end

  def cast(string) when is_binary(string) do
    case string do
      "device" ->
        {:ok, :device}

      "server" ->
        {:ok, :server}

      # deprecated names
      "producer" ->
        {:ok, :device}

      "consumer" ->
        {:ok, :server}

      _ ->
        :error
    end
  end

  def cast(int) when is_integer(int) do
    load(int)
  end

  def cast(_), do: :error

  def cast!(value) do
    case cast(value) do
      {:ok, ownership} ->
        ownership

      :error ->
        raise ArgumentError, message: "#{inspect(value)} is not a valid ownership representation"
    end
  end

  @impl true
  def dump(ownership) when is_atom(ownership) do
    case ownership do
      :device -> {:ok, @interface_ownership_device}
      :server -> {:ok, @interface_ownership_server}
      _ -> :error
    end
  end

  def dump!(ownership) when is_atom(ownership) do
    case dump(ownership) do
      {:ok, ownership_int} -> ownership_int
      :error -> raise ArgumentError, message: "#{inspect(ownership)} is not a valid ownership"
    end
  end

  @impl true
  def load(ownership_int) when is_integer(ownership_int) do
    case ownership_int do
      @interface_ownership_device -> {:ok, :device}
      @interface_ownership_server -> {:ok, :server}
      _ -> :error
    end
  end

  def to_int(ownership) when is_atom(ownership) do
    dump!(ownership)
  end

  def from_int(int) when is_integer(int) do
    cast!(int)
  end
end
