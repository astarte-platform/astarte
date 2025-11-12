#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.Import.CLI do
  alias Astarte.Import.PopulateDB
  require Logger

  @chunk_size 4096

  def main(args) do
    with {:started, {:ok, _}} <- {:started, Application.ensure_all_started(:astarte_import)},
         [realm, file_name] <- args,
         true <- String.valid?(realm),
         true <- String.valid?(file_name),
         {:ok, file} <- File.open(file_name, [:read]),
         data when is_binary(data) <- IO.read(file, @chunk_size) do
      more_data = fn state ->
        with data when is_binary(data) <- IO.read(file, @chunk_size) do
          {data, state}
        else
          :eof ->
            {"", state}

          {:error, reason} ->
            Logger.error("Cannot read #{file_name}: #{inspect(reason)}.", realm: realm)
            throw({:error, :cannot_read})

          any ->
            Logger.error("Cannot read #{file_name}. unexpected: #{inspect(any)}.", realm: realm)
            throw({:error, :cannot_read})
        end
      end

      case Xandra.Cluster.run(
             :astarte_data_access_xandra,
             &PopulateDB.populate(&1, realm, data, more_data)
           ) do
        {:error, reason} ->
          Logger.error("Import failed: #{inspect(reason)}.", realm: realm)

        _ ->
          :ok
      end
    else
      {:started, {:error, reason}} ->
        Logger.error("Cannot ensure all applications startup: #{inspect(reason)}")

      {:error, :enoent} ->
        [realm, file_name] = args
        Logger.error("File not found: #{file_name}.", realm: realm)

      {:error, :eacces} ->
        [realm, file_name] = args
        Logger.error("Cannot access: #{file_name}.", realm: realm)

      any ->
        Logger.error("Invalid args: #{inspect(any)}. exiting.")
    end
  end
end
