#
# This file is part of Astarte.
#
# Copyright 2018 - 2024 SECO Mind Srl
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

defmodule Astarte.DataAccess.Device do
  require Logger
  alias Astarte.DataAccess.XandraUtils
  alias Astarte.Core.Device

  @spec interface_version(String.t(), Device.device_id(), String.t()) ::
          {:ok, integer} | {:error, atom}
  def interface_version(realm, device_id, interface_name) do
    XandraUtils.run(realm, &do_interface_version(&1, &2, device_id, interface_name))
  end

  defp do_interface_version(conn, keyspace_name, device_id, interface_name) do
    statement = """
    SELECT introspection
    FROM #{keyspace_name}.devices
    WHERE device_id=:device_id
    """

    with {:ok, %Xandra.Page{} = page} <-
           XandraUtils.retrieve_page(conn, statement, %{device_id: device_id}),
         {:ok, introspection} <- retrieve_introspection(page),
         {:ok, major} <- retrieve_major(introspection, interface_name) do
      {:ok, major}
    end
  end

  defp retrieve_introspection(page) do
    case Enum.to_list(page) do
      [] ->
        {:error, :device_not_found}

      # We're here if the device has been registered but has not declared its introspection yet
      [%{introspection: nil}] ->
        {:ok, %{}}

      [%{introspection: introspection}] ->
        {:ok, introspection}
    end
  end

  defp retrieve_major(introspection, interface_name) do
    with :error <- Map.fetch(introspection, interface_name) do
      {:error, :interface_not_in_introspection}
    end
  end
end
