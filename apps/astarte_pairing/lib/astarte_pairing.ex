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

defmodule Astarte.Pairing do
  @moduledoc false

  use Application

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.RPC.Handler

  alias Astarte.RPC.Protocol.Pairing, as: Protocol

  def start(_type, _args) do
    Config.init!()

    children = [
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: Handler]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
