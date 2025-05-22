#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule AstarteDevTool.Utilities.Path do
  @moduledoc false
  def path_from(path) when is_bitstring(path) do
    abs_path = Path.expand(path)
    if File.exists?(abs_path), do: {:ok, abs_path}, else: {:error, "Invalid path: #{path}"}
  end

  def directory_path_from(path) when is_bitstring(path) do
    case path_from(path) do
      {:ok, abs_path} ->
        if File.dir?(abs_path), do: {:ok, abs_path}, else: {:error, "#{path} is not a directory"}

      error ->
        error
    end
  end
end
