#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.RPC.ConfigTest do
  use ExUnit.Case, async: true

  alias Astarte.RPC.Config

  describe "cluster_topologies!/0" do
    test "with `:none` strategy returns empty list" do
      assert cluster_topologies(:none, []) == []
      assert cluster_topologies(:none, [:astarte_data_updater_plant]) == []
      assert cluster_topologies(:none, [:astarte_vmq_plugin]) == []
      assert cluster_topologies(:none, [:astarte_data_updater_plant, :astarte_vmq_plugin]) == []
    end

    test "with `:kubernetes` strategy and data updater plant returns expected data" do
      assert [dup] = cluster_topologies(:kubernetes, [:astarte_data_updater_plant])
      assert {:data_updater_plant_k8s, opts} = dup
      assert opts[:strategy] == Elixir.Cluster.Strategy.Kubernetes
      config = opts[:config]
      assert config[:mode] == :ip
      assert config[:kubernetes_node_basename] == "astarte_data_updater_plant"
      assert config[:kubernetes_selector] == Config.dup_clustering_kubernetes_selector!()
      assert config[:kubernetes_namespace] == Config.clustering_kubernetes_namespace!()
      assert config[:polling_interval] == 10_000
    end

    test "with `:kubernetes` strategy and vernemq returns expected data" do
      assert [dup] = cluster_topologies(:kubernetes, [:astarte_vmq_plugin])
      assert {:vernemq_k8s, opts} = dup
      assert opts[:strategy] == Elixir.Cluster.Strategy.Kubernetes
      config = opts[:config]
      assert config[:mode] == :hostname
      assert config[:kubernetes_node_basename] == "VerneMQ"

      assert config[:kubernetes_ip_lookup_mode] == :pods
      assert config[:kubernetes_selector] == Config.vernemq_clustering_kubernetes_selector!()
      assert config[:kubernetes_namespace] == Config.clustering_kubernetes_namespace!()
      assert config[:polling_interval] == 10_000
    end

    test "with `:kubernetes` strategy accepts multiple services" do
      config = cluster_topologies(:kubernetes, [:astarte_data_updater_plant, :astarte_vmq_plugin])
      services = Keyword.keys(config)
      assert :data_updater_plant_k8s in services
      assert :vernemq_k8s in services
    end

    test "with `:docker_compose` strategy and data updater plant returns expected data" do
      assert [dup] = cluster_topologies(:docker_compose, [:astarte_data_updater_plant])
      assert {:data_updater_plant, opts} = dup
      assert opts[:strategy] == Elixir.Cluster.Strategy.DNSPoll
      config = opts[:config]
      assert config[:query] == "astarte-data-updater-plant"
      assert config[:node_basename] == "astarte_data_updater_plant"
      assert config[:polling_interval] == 5000
    end

    test "with `:docker_compose` strategy and vernemq returns expected data" do
      assert [dup] = cluster_topologies(:docker_compose, [:astarte_vmq_plugin])
      assert {:vernemq, opts} = dup
      assert opts[:strategy] == Elixir.Cluster.Strategy.DNSPoll
      config = opts[:config]
      assert config[:query] == "vernemq"
      assert config[:node_basename] == "VerneMQ"
      assert config[:polling_interval] == 5000
    end

    test "with `:docker_compose` strategy accepts multiple services" do
      config =
        cluster_topologies(:docker_compose, [:astarte_data_updater_plant, :astarte_vmq_plugin])

      services = Keyword.keys(config)
      assert :data_updater_plant in services
      assert :vernemq in services
    end
  end

  defp cluster_topologies(strategy, services, opts \\ []) do
    Config.put_clustering_strategy(strategy)
    Config.put_astarte_services(services)

    for {option, value} <- opts do
      Application.put_env(:astarte_rpc, option, value)
    end

    Config.reload_vernemq_clustering_kubernetes_selector()
    Config.reload_vernemq_clustering_kubernetes_service_name()
    Config.reload_dup_clustering_kubernetes_selector()
    Config.reload_clustering_kubernetes_namespace()

    Config.cluster_topologies!()
  end
end
