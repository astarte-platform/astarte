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

defmodule AstarteDevTool.Commands.System.Up do
  @moduledoc false
  alias AstarteDevTool.Constants.System, as: Constants

  def exec(path) do
    with {_result, 0} <-
           System.cmd(
             Constants.command(),
             Constants.command_initialize_keys(),
             Constants.base_opts() ++ [cd: path]
           ),
         {_result, 0} <-
           System.cmd(
             Constants.command(),
             Constants.command_up_args(),
             Constants.base_opts() ++ [cd: path]
           ) do
      :ok
    else
      {:process, _} -> {:error, "The system is already running"}
      {result, exit_code} -> {:error, "Cannot exec system.up: #{result}, #{exit_code}"}
    end
  end
end
