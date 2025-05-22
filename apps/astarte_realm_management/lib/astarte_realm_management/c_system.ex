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

defmodule CSystem do
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Repo
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
          {:ok, Ecto.UUID.t()} | {:error, :timeout}
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

  @spec schema_versions :: [Ecto.UUID.t()]
  def schema_versions do
    local_version = query_local_schema_version()
    peers_version = query_peers_schema_versions()

    [local_version | peers_version]
    |> Enum.uniq()
  end

  @spec schema_versions :: [Ecto.UUID.t()]
  def query_peers_schema_versions do
    from(p in "peers", select: p.schema_version)
    |> Repo.all(prefix: "system", consistency: Consistency.domain_model(:read))
    |> Enum.uniq()
  end

  @spec schema_versions :: Ecto.UUID.t()
  def query_local_schema_version do
    from(l in "local", select: l.schema_version)
    |> Repo.get_by!([key: "local"],
      prefix: "system",
      consistency: Consistency.domain_model(:read)
    )
  end
end
