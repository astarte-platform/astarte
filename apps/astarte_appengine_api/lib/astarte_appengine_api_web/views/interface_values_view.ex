#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.InterfaceValuesView do
  use Astarte.AppEngine.APIWeb, :view
  alias Astarte.AppEngine.APIWeb.InterfaceValuesView

  def render("index.json", %{interfaces: interfaces}) do
    %{data: render_many(interfaces, InterfaceValuesView, "interface_values.json")}
  end

  def render("show.json", %{interface_values: interface_values}) do
    render_struct = %{
      data: render_one(interface_values.data, InterfaceValuesView, "interface_values.json")
    }

    if interface_values.metadata != nil do
      Map.put(render_struct, :metadata, interface_values.metadata)
    else
      render_struct
    end
  end

  def render("interface_values.json", %{interface_values: interface_values}) do
    interface_values
  end
end
