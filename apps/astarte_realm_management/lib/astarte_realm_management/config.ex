#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.RealmManagement.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """
  use Skogsra

  alias Astarte.DataAccess.Config, as: DataAccessConfig

  @envdoc """
  "Disables the authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.
  """
  app_env :disable_authentication, :astarte_realm_management, :disable_authentication,
    os_env: "REALM_MANAGEMENT_API_DISABLE_AUTHENTICATION",
    type: :boolean,
    default: false

  @doc """
  Returns true if the authentication is disabled.
  """
  def authentication_disabled?, do: disable_authentication!()

  @envdoc "The Erlang cluster strategy to use. One of `none`, `kubernetes`. Defaults to `none`."
  app_env(
    :clustering_strategy,
    :astarte_realm_management,
    :clustering_strategy,
    os_env: "CLUSTERING_STRATEGY",
    type: Astarte.RealmManagement.Config.ClusteringStrategy,
    default: "none"
  )

  @envdoc "The Endpoint label to use to query Kubernetes to find data updater plant instances. Defaults to `app=astarte-data-updater-plant`."
  app_env(
    :dup_clustering_kubernetes_selector,
    :astarte_realm_management,
    :dup_clustering_kubernetes_selector,
    os_env: "DATA_UPDATER_PLANT_CLUSTERING_KUBERNETES_SELECTOR",
    type: :binary,
    default: "app=astarte-data-updater-plant"
  )

  @envdoc "The Kubernetes namespace to use when `kubernetes` Erlang clustering strategy is used. Defaults to `astarte`."
  app_env(
    :clustering_kubernetes_namespace,
    :astarte_realm_management,
    :clustering_kubernetes_namespace,
    os_env: "CLUSTERING_KUBERNETES_NAMESPACE",
    type: :binary,
    default: "astarte"
  )

  # Define the cluster_topologies! function directly in this module
  def cluster_topologies!() do
    case clustering_strategy!() do
      "none" ->
        []

      "kubernetes" ->
        [
          data_updater_plant_k8s: [
            strategy: Elixir.Cluster.Strategy.Kubernetes,
            config: [
              mode: :ip,
              kubernetes_node_basename: :astarte_realmmanagement,
              kubernetes_selector: dup_clustering_kubernetes_selector!(),
              kubernetes_namespace: clustering_kubernetes_namespace!(),
              polling_interval: 10_000
            ]
          ]
        ]

      "docker-compose" ->
        [
          data_updater_plant: [
            strategy: Elixir.Cluster.Strategy.DNSPoll,
            config: [
              polling_interval: 5_000,
              query: "astarte-data-updater-plant",
              node_basename: "astarte_data_updater_plant"
            ]
          ]
        ]
    end
  end

  @doc """
  Returns Cassandra nodes formatted in the Xandra format.
  """
  defdelegate xandra_options!, to: DataAccessConfig
end
