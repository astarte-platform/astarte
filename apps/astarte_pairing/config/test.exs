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

use Mix.Config

config :astarte_rpc, :amqp_connection,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :astarte_pairing, :broker_url,
  "ssl://broker.beta.astarte.cloud:8883/"

config :astarte_pairing, :cfssl_url,
  System.get_env("CFSSL_API_URL") || "http://ispirata-docker-alpine-cfssl-autotest:8080"

config :cqerl, :cassandra_nodes,
  [{System.get_env("CASSANDRA_DB_HOST") || "scylladb-scylla", System.get_env("CASSANDRA_DB_PORT") || 9042}]

config :bcrypt_elixir,
  log_rounds: 4
