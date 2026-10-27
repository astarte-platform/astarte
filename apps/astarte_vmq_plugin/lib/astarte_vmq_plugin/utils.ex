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

defmodule Astarte.VMQ.Plugin.Utils do
  @moduledoc """
  Utilities module
  """

  @doc """
  Return functions with the same format of the one returned by :vmq_reg.direct_plugin_exports.
  Useful to make sure we can run the application interactively without Verne
  """
  def empty_plugin_functions do
    empty_fun_0 = fn -> :ok end
    empty_fun_3 = fn _, _, _ -> :ok end

    {empty_fun_0, empty_fun_3, {nil, nil}}
  end
end
