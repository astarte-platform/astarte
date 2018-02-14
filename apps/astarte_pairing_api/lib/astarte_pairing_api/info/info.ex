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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.Pairing.API.Info do
  @moduledoc """
  The Info context.
  """

  alias Astarte.Pairing.API.Info.BrokerInfo
  alias Astarte.Pairing.API.RPC.AMQPClient

  @doc """
  Gets broker_info.

  Raises if the Broker info does not exist.

  ## Examples

      iex> get_broker_info!()
      %BrokerInfo{url: "ssl://broker.example.com:1234", version: "1"}

  """
  def get_broker_info! do
    case AMQPClient.get_info do
      {:ok, %{url: url, version: version}} ->
        %BrokerInfo{url: url, version: version}

      _ ->
        raise "Broker info unavailable"
    end
  end
end
