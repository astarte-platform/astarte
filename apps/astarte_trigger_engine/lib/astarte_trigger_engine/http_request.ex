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

defmodule Astarte.TriggerEngine.HttpRequest do
  alias Astarte.TriggerEngine.HttpRequest
  alias Astarte.TriggerEngine.Templating.HeadersTemplate
  alias Astarte.TriggerEngine.Templating.StructTemplate
  alias Astarte.TriggerEngine.Templating.TextTemplate
  alias Astarte.TriggerEngine.Templating.URLTemplate

  defstruct [
    :method,
    :url,
    :headers,
    :body
  ]

  def build_http_request(template, vars) do
    IO.puts(inspect(template.url))

    %HttpRequest{
      method: template.method,
      url: template.url |> URLTemplate.merge(vars) |> URLTemplate.apply(),
      headers: template.headers |> HeadersTemplate.merge(vars) |> HeadersTemplate.apply(),
      body: build_body(template.body, vars, template.body_type)
    }
  end

  defp build_body(template, vars, :json) do
    template
    |> StructTemplate.merge(vars)
    |> StructTemplate.apply()
    |> Poison.encode!()
  end

  defp build_body(template, vars, :text) do
    template
    |> TextTemplate.merge(vars)
    |> TextTemplate.apply()
  end

  defp build_body(_template, _vars, :no_body) do
    nil
  end
end
