#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin.ConfigTest do
  use ExUnit.Case

  alias Astarte.VMQ.Plugin.Config

  test "config init correctly converts amqp_options to elixir strings" do
    opts = [username: ~c"user", password: ~c"password", virtual_host: ~c"/"]

    old_opts = Config.amqp_options()

    Application.put_env(:astarte_vmq_plugin, :amqp_options, opts)
    Config.init()

    new_opts = Config.amqp_options()
    assert Keyword.get(new_opts, :username) == "user"
    assert Keyword.get(new_opts, :password) == "password"
    assert Keyword.get(new_opts, :virtual_host) == "/"

    on_exit(fn ->
      Application.put_env(:astarte_vmq_plugin, :amqp_options, old_opts)
    end)
  end

  test "config init correctly converts data_queue_prefix to elixir string" do
    data_queue_prefix = ~c"test_erlang_str"

    old_data_queue_prefix = Config.data_queue_prefix()

    Application.put_env(:astarte_vmq_plugin, :data_queue_prefix, data_queue_prefix)
    Config.init()

    assert Config.data_queue_prefix() == to_string(data_queue_prefix)

    on_exit(fn ->
      Application.put_env(:astarte_vmq_plugin, :data_queue_prefix, old_data_queue_prefix)
    end)
  end

  test "config init correctly converts cassandra_nodes to elixir string" do
    erlang_cassandra_nodes = [~c"something"]

    elixir_cassandra_nodes = ["something"]

    Application.put_env(:astarte_vmq_plugin, :cassandra_nodes, erlang_cassandra_nodes)
    Config.init()

    assert elixir_cassandra_nodes == Config.xandra_options!()[:nodes]

    on_exit(fn ->
      Application.put_env(:astarte_vmq_plugin, :data_queue_prefix, elixir_cassandra_nodes)
    end)
  end
end
