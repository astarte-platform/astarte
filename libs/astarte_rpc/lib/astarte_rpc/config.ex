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

defmodule Astarte.RPC.Config do
  use Skogsra

  alias Astarte.RPC.Config

  @envdoc "The name of the main application"
  app_env :pool_size, :astarte_rpc, :pool_size,
    os_env: "ASTARTE_RPC_POOL_SIZE",
    type: :integer,
    default: 1

  @envdoc "The Erlang cluster strategy to use. One of `none`, `kubernetes`, `docker-compose`. Defaults to `none`."
  app_env :clustering_strategy, :astarte_rpc, :clustering_strategy,
    os_env: "CLUSTERING_STRATEGY",
    type: Config.ClusteringStrategy,
    default: :none

  @envdoc "The astarte services to include in the clustering. Defaults to `[]`."
  app_env :astarte_services, :astarte_rpc, :astarte_services,
    type: Config.AstarteServices,
    binding_skip: [:system],
    default: []

  @envdoc "The endpoint label to query to get other data updater plant instances. Defaults to `app=astarte-data-updater-plant`."
  app_env :dup_clustering_kubernetes_selector, :astarte_rpc, :dup_clustering_kubernetes_selector,
    os_env: "DATA_UPDATER_PLANT_CLUSTERING_KUBERNETES_SELECTOR",
    type: :binary,
    default: "app=astarte-data-updater-plant"

  @envdoc "The endpoint label to query to get other pairing instances. Defaults to `app=astarte-pairing`."
  app_env :pairing_clustering_kubernetes_selector, :astarte_rpc, :pairing_clustering_kubernetes_selector,
    os_env: "PAIRING_CLUSTERING_KUBERNETES_SELECTOR",
    type: :binary,
    default: "app=astarte-pairing"

  @envdoc "The endpoint label to query to get other realm management instances. Defaults to `app=astarte-realm-management`."
  app_env :rm_clustering_kubernetes_selector, :astarte_rpc, :rm_clustering_kubernetes_selector,
    os_env: "REALM_MANAGEMENT_CLUSTERING_KUBERNETES_SELECTOR",
    type: :binary,
    default: "app=astarte-realm-management"

  @envdoc "The Pod label to use to query Kubernetes to find vernemq instances. Defaults to `app=astarte-vernemq`."
  app_env :vernemq_clustering_kubernetes_selector,
          :astarte_rpc,
          :vernemq_clustering_kubernetes_selector,
          os_env: "VERNEMQ_CLUSTERING_KUBERNETES_SELECTOR",
          type: :binary,
          default: "app=astarte-vernemq"

  @envdoc "The name of the Kubernetes service to use to query Kubernetes to find vernemq instances. Defaults to `astarte-vernemq`."
  app_env :vernemq_clustering_kubernetes_service_name,
          :astarte_rpc,
          :vernemq_clustering_kubernetes_service_name,
          os_env: "VERNEMQ_CLUSTERING_KUBERNETES_SERVICE_NAME",
          type: :binary,
          default: "astarte-vernemq"

  @envdoc "The Kubernetes namespace to use when `kubernetes` Erlang clustering strategy is used. Defaults to `astarte`."
  app_env :clustering_kubernetes_namespace, :astarte_rpc, :clustering_kubernetes_namespace,
    os_env: "CLUSTERING_KUBERNETES_NAMESPACE",
    type: :binary,
    default: "astarte"

  def cluster_topologies! do
    case clustering_strategy!() do
      :none ->
        []

      :kubernetes ->
        kubernetes_services()
        |> Map.take(astarte_services!())
        |> Map.values()

      :docker_compose ->
        docker_compose_services()
        |> Map.take(astarte_services!())
        |> Map.values()
    end
  end

  defp kubernetes_services do
    %{
      astarte_data_updater_plant:
        {:data_updater_plant_k8s,
         [
           strategy: Elixir.Cluster.Strategy.Kubernetes,
           config: [
             mode: :ip,
             kubernetes_node_basename: "astarte_data_updater_plant",
             kubernetes_selector: dup_clustering_kubernetes_selector!(),
             kubernetes_namespace: clustering_kubernetes_namespace!(),
             polling_interval: 10_000
           ]
         ]},
      astarte_pairing:
        {:pairing_k8s,
         [
           strategy: Elixir.Cluster.Strategy.Kubernetes,
           config: [
             mode: :ip,
             kubernetes_node_basename: "astarte_pairing",
             kubernetes_selector: pairing_clustering_kubernetes_selector!(),
             kubernetes_namespace: clustering_kubernetes_namespace!(),
             polling_interval: 10_000
           ]
         ]},
      astarte_realm_management:
        {:realm_management_k8s,
         [
           strategy: Elixir.Cluster.Strategy.Kubernetes,
           config: [
             mode: :ip,
             kubernetes_node_basename: "astarte_realm_management",
             kubernetes_selector: rm_clustering_kubernetes_selector!(),
             kubernetes_namespace: clustering_kubernetes_namespace!(),
             polling_interval: 10_000
           ]
         ]},
      astarte_vmq_plugin:
        {:vernemq_k8s,
         [
           strategy: Elixir.Cluster.Strategy.Kubernetes,
           config: [
             mode: :hostname,
             kubernetes_service_name: vernemq_clustering_kubernetes_service_name!(),
             kubernetes_node_basename: "VerneMQ",
             kubernetes_ip_lookup_mode: :pods,
             kubernetes_selector: vernemq_clustering_kubernetes_selector!(),
             kubernetes_namespace: clustering_kubernetes_namespace!(),
             polling_interval: 10_000
           ]
         ]}
    }
  end

  defp docker_compose_services do
    %{
      astarte_data_updater_plant:
        {:data_updater_plant,
         [
           strategy: Elixir.Cluster.Strategy.DNSPoll,
           config: [
             polling_interval: 5_000,
             query: "astarte-data-updater-plant",
             node_basename: "astarte_data_updater_plant"
           ]
         ]},
      astarte_pairing:
        {:pairing,
         [
           strategy: Elixir.Cluster.Strategy.DNSPoll,
           config: [
             polling_interval: 5_000,
             query: "astarte-pairing",
             node_basename: "astarte_pairing"
           ]
         ]},
      astarte_realm_management:
        {:realm_management,
         [
           strategy: Elixir.Cluster.Strategy.DNSPoll,
           config: [
             polling_interval: 5_000,
             query: "astarte-realm-management",
             node_basename: "astarte_realm_management"
           ]
         ]},
      astarte_vmq_plugin:
        {:vernemq,
         [
           strategy: Elixir.Cluster.Strategy.DNSPoll,
           config: [
             polling_interval: 5_000,
             query: "vernemq",
             node_basename: "VerneMQ"
           ]
         ]}
    }
  end
end
