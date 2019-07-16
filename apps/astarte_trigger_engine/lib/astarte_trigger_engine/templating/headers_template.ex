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
#

defmodule Astarte.TriggerEngine.Templating.HeadersTemplate do
  alias Astarte.TriggerEngine.Templating.HeadersTemplate

  defstruct [
    :headers
  ]

  def new(headers) do
    Map.put(%HeadersTemplate{}, :headers, headers)
  end

  def apply(template) do
    template.headers
  end

  def merge(template, vars) do
    Enum.reduce(vars, template, fn {var_key, var_value}, template_acc ->
      put(template_acc, var_key, var_value)
    end)
  end

  def put(template, var_key, var_value) when is_binary(var_value) do
    new_headers =
      Enum.map(template.headers, fn entry ->
        String.replace(entry, "%{#{var_key}}", var_value)
      end)

    Map.put(template, :headers, new_headers)
  end

  def put(template, _var_key, _var_value) do
    template
  end
end
