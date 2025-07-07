#
# This file is part of Astarte.
#
# Copyright 2020 - 2025 SECO Mind Srl
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

defmodule Astarte.DataAccess.CSystem do
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.CSystem
  alias Astarte.DataAccess.Consistency

  import Ecto.Query

  @agreement_sleep_millis 200

  def run_with_schema_agreement(opts \\ [], fun) when is_function(fun) do
    timeout = Keyword.get(opts, :timeout, 30000)
    expect_change = Keyword.get(opts, :expect_change, false)

    with {:ok, initial} <- wait_schema_agreement(timeout),
         out = fun.(),
         {:ok, final} <- wait_schema_agreement(timeout) do
      unless expect_change and initial == final do
        out
      else
        {:error, :no_schema_change}
      end
    end
  end

  def wait_schema_agreement(timeout) when is_integer(timeout) and timeout >= 0 do
    case schema_versions() do
      [version] ->
        {:ok, version}

      _ ->
        case min(timeout, @agreement_sleep_millis) do
          0 ->
            {:error, :timeout}

          millis ->
            Process.sleep(millis)
            wait_schema_agreement(timeout - millis)
        end
    end
  end

  def schema_versions() do
    local_version = query_local_schema_version()
    peers_versions = query_peers_schema_versions()
    Enum.uniq([local_version | peers_versions])
  end

  def query_peers_schema_versions() do
    query =
      from(peers in "peers",
        prefix: "system",
        select: peers.schema_version
      )

    Repo.all(query, consistency: Consistency.domain_model(:read))
    |> Stream.uniq()
    |> Enum.to_list()
  end

  def query_local_schema_version() do
    query =
      from(locals in "local",
        prefix: "system",
        where: locals.key == "local",
        select: locals.schema_version
      )

    Repo.one!(query, consistency: Consistency.domain_model(:read))
  end

  def execute_schema_change(query) do
    consistency = Consistency.domain_model(:write)

    opts = [
      consistency: consistency,
      timeout: 60_000
    ]

    result =
      CSystem.run_with_schema_agreement(fn ->
        Repo.query(query, [], opts)
      end)

    case result do
      {:error, :timeout} ->
        %Xandra.Error{reason: :agreement_timeout, message: "Schema agreement wait timeout."}

      {:error, :no_schema_change} ->
        %Xandra.Error{
          reason: :no_schema_change,
          message: "Statement did not change the schema_version."
        }

      any ->
        any
    end
  end
end
