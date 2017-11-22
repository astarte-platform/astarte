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

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :astarte_trigger_engine, :amqp_consumer_options,
  host: "localhost",
  username: "guest",
  password: "guest",
  virtual_host: "/",
  port: 5672

config :astarte_trigger_engine, :amqp_events_queue_name,
  "astarte_events"

config :astarte_trigger_engine, :amqp_events_exchange_name,
  "astarte_events"

config :astarte_trigger_engine, :amqp_events_routing_key,
  "trigger_engine"

import_config "#{Mix.env}.exs"
