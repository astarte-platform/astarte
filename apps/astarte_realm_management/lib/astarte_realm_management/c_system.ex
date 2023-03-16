#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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
  @agreement_sleep_millis 200

  def run_with_schema_agreement(conn, opts \\ [], fun) when is_function(fun) do
    timeout = Keyword.get(opts, :timeout, 30000)
    expect_change = Keyword.get(opts, :expect_change, false)

    with {:ok, initial} <- wait_schema_agreement(conn, timeout),
         out = fun.(),
         {:ok, final} <- wait_schema_agreement(conn, timeout) do
      unless expect_change and initial == final do
        out
      else
        {:error, :no_schema_change}
      end
    end
  end

  def wait_schema_agreement(conn, timeout) when is_integer(timeout) and timeout >= 0 do
    case schema_versions(conn) do
      {:ok, [version]} ->
        {:ok, version}

      {:ok, _versions} ->
        millis = min(timeout, @agreement_sleep_millis)

        if millis == 0 do
          {:error, :timeout}
        else
          Process.sleep(millis)
          wait_schema_agreement(conn, timeout - millis)
        end

      any_other ->
        any_other
    end
  end

  def schema_versions(conn) do
    with {:ok, local_version} <- query_local_schema_version(conn),
         {:ok, peers_versions} <- query_peers_schema_versions(conn) do
      {:ok, Enum.uniq([local_version | peers_versions])}
    end
  end

  def query_peers_schema_versions(conn) do
    query = "SELECT schema_version FROM system.peers"

    with {:ok, res} <- Xandra.execute(conn, query, %{}, consistency: :one) do
      schema_versions =
        res
        |> Stream.map(&Map.fetch!(&1, :schema_version))
        |> Stream.uniq()
        |> Enum.to_list()

      {:ok, schema_versions}
    end
  end

  def query_local_schema_version(conn) do
    query = "SELECT schema_version FROM system.local WHERE key='local'"

    with {:ok, res} <- Xandra.execute(conn, query, %{}, consistency: :one) do
      schema_version =
        res
        |> Enum.take(1)
        |> List.first()
        |> Map.fetch!(:schema_version)

      {:ok, schema_version}
    end
  end
end
