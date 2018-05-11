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

defmodule Astarte.Housekeeping.Supervisor do
  use Supervisor

  alias Astarte.RPC.Protocol.Housekeeping
  alias Astarte.Housekeeping.RPC.Handler

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      worker(Astarte.Housekeeping.Engine, []),
      worker(Astarte.RPC.AMQP.Server, [[amqp_queue: Housekeeping.amqp_queue(), handler: Handler]])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
