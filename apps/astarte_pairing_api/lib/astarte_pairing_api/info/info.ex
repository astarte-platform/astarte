#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.Pairing.API.Info do
  @moduledoc """
  The Info context.
  """

  alias Astarte.Pairing.API.Info.DeviceInfo
  alias Astarte.Pairing.API.RPC.Pairing

  @doc """
  Retrieves device info.
  """
  def get_device_info(realm, hw_id, secret) do
    with {:ok, %{version: version, status: status, protocols: protocols}} <-
           Pairing.get_info(realm, hw_id, secret) do
      device_info = %DeviceInfo{
        version: version,
        status: status,
        protocols: protocols
      }

      {:ok, device_info}
    else
      {:error, :forbidden} ->
        {:error, :forbidden}

      {:error, _other} ->
        {:error, :rpc_error}
    end
  end
end
