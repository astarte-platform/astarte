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

defmodule Astarte.AppEngine.API.DataTransmitter.MQTTClient do
  use GenMQTT

  @exactly_once_qos 2

  def start_link(opts \\ []) do
    full_opts =
      opts
      |> Keyword.put(:name, __MODULE__)
      |> Keyword.put(:client, generate_client_id())

    GenMQTT.start_link(__MODULE__, [], full_opts)
  end

  def publish(topic, payload) do
    GenMQTT.publish(__MODULE__, topic, payload, @exactly_once_qos, false)
  end

  defp generate_client_id do
    :crypto.strong_rand_bytes(10)
    |> Base.encode16()
  end
end
