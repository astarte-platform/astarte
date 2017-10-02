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

defmodule Astarte.Pairing.Config do
  @moduledoc """
  This module helps the access to the runtime configuration of Astarte Pairing
  """

  @doc """
  Returns the rpc_queue contained in the config.

  Raises if it doesn't exist since it's required.
  """
  def rpc_queue! do
    Application.fetch_env!(:astarte_pairing, :rpc_queue)
  end

  @doc """
  Returns the amqp_connection options or an empty list if they're not set.
  """
  def amqp_options do
    Application.get_env(:astarte_pairing, :amqp_connection, [])
  end

  @doc """
  Returns the broker_url contained in the config.

  Raises if it doesn't exist since it's required.
  """
  def broker_url! do
    Application.fetch_env!(:astarte_pairing, :broker_url)
  end
end
