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

defmodule AstarteDevTool.Utilities.System do
  @field_separator ","
  @parse_regex ~r/^(?<id>\w+)#{@field_separator}(?:astarte-(?<name>[\w-]+)-\d)$/

  def system_status(path) do
    command = "docker"

    args =
      ~w(ps -a --no-trunc --format {{.ID}}#{@field_separator}{{.Names}} -f status=running -f label=com.docker.compose.project.working_dir=#{path})

    {pids_str, 0} = System.cmd(command, args, cd: path)

    {:ok,
     pids_str
     |> String.split("\n", trim: true)
     |> Enum.map(&Regex.named_captures(@parse_regex, &1))}
  end
end
