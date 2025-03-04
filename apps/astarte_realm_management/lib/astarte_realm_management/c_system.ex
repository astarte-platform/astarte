#
# This file is part of Astarte.
#
# Copyright 2020 - 2023 SECO Mind Srl
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

defmodule CSystem do
  alias Astarte.RealmManagement.Repo
  import Ecto.Query

  @agreement_sleep_millis 200

  @type function_result :: any()

  @spec run_with_schema_agreement(Keyword.t(), (-> function_result())) ::
          function_result() | {:error, :no_schema_change} | {:error, :timeout}
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

  @spec wait_schema_agreement(integer()) ::
          {:ok, Astarte.RealmManagement.UUID.t()} | {:error, :timeout}
  def wait_schema_agreement(timeout) when is_integer(timeout) and timeout >= 0 do
    case schema_versions() do
      [version] ->
        {:ok, version}

      _versions ->
        millis = min(timeout, @agreement_sleep_millis)

        case millis do
          0 ->
            {:error, :timeout}

          _ ->
            Process.sleep(millis)
            wait_schema_agreement(timeout - millis)
        end
    end
  end

  @spec schema_versions :: [Astarte.RealmManagement.UUID.t()]
  def schema_versions do
    local_version = query_local_schema_version()
    peers_version = query_peers_schema_versions()

    [local_version | peers_version]
    |> Enum.uniq()
  end

  @spec schema_versions :: [Astarte.RealmManagement.UUID.t()]
  def query_peers_schema_versions do
    from(p in "peers", select: p.schema_version)
    |> Repo.all(prefix: "system", consistency: :one)
    |> Enum.uniq()
  end

  @spec schema_versions :: Astarte.RealmManagement.UUID.t()
  def query_local_schema_version do
    from(l in "local", select: l.schema_version)
    |> Repo.get_by!([key: "local"], prefix: "system", consistency: :one)
  end

  @spec execute_schema_change(String.t()) ::
          {:ok, Ecto.Adapters.SQL.query_result()} | {:error, Exception.t()} | Xandra.Error.t()
  def execute_schema_change(query) do
    query_params = []

    result =
      run_with_schema_agreement(fn ->
        Repo.query(query, query_params, consistency: :each_quorum, timeout: 60_000)
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
