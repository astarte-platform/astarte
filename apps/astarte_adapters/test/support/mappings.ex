#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Adapters.Mappings do
  @moduledoc false
  use Astarte.Adapters

  alias Astarte.Adapters.ComplexStruct
  alias Astarte.Adapters.SimpleStruct

  transform map_to_simple_struct do
    @source map()
    @returns SimpleStruct.t()
    field :id <- :id
    field :name <- :name, required: false
    post_process &struct!(SimpleStruct, &1)
  end

  transform map_to_complex_struct do
    @source %{a: %{id: integer(), name: String.t() | nil}, b: [map()]}
    @returns ComplexStruct.t()

    field :id <- [:a, :id]
    field :name <- [:a, :name], required: false

    field :children <- :b, fn children, _source -> Enum.map(children, &map_to_simple_struct/1) end

    post_process &struct!(ComplexStruct, &1)
  end

  transform complex_struct_to_map do
    @source ComplexStruct.t()
    @returns %{a: %{id: integer(), name: String.t()}, b: [%{id: integer(), name: String.t()}]}

    field [:a, :id] <- :id
    field [:a, :name] <- :name, required: false

    field :b <- :children, fn children, _source -> Enum.map(children, &Map.from_struct/1) end
  end

  transform string_map_to_string do
    @source %{required(String.t()) => String.t(), required(String.t()) => String.t()}
    @returns String.t()
    keep "a", "b"
    post_process fn %{"a" => a, "b" => b} -> a <> b end
  end

  transform full_dsl_test do
    @source {integer(), String.t(), String.t(), String.t()}
    @returns %{
      id: integer(),
      role: String.t(),
      is_active: bool(),
      role_upper: String.t(),
      full_name: String.t(),
      processed_at: atom()
    }

    pre_process fn {id, first, last, role} ->
      %{id: id, first: first, last: last, role: role, meta: %{active: true}}
    end

    keep :id, :role
    field :is_active <- [:meta, :active]
    field :role_upper <- :role, fn role, _source -> String.upcase(role) end
    field :full_name, fn source -> "#{source.first} #{source.last}" end
    post_process fn result -> Map.put(result, :processed_at, :now) end
  end

  transform computed_fields_only do
    @source %{x: integer(), y: integer()}
    @source %{combined: integer(), static: String.t()}
    field :combined, fn src -> src.x + src.y end
    field :static, fn _src -> "always_this" end
  end

  transform mixed_keep_test do
    @source %{x: integer(), y: integer()}
    @source %{combined: integer(), static: String.t()}
    keep :atom_key, "string_key", :another_atom
  end

  transform with_private_delegation do
    @source %{data: String.t(), meta: map()}
    @returns map()

    field :data <- :data
    field :metadata <- :meta, fn meta, _source -> process_metadata(meta) end
  end

  transformp process_metadata do
    field :status <- :state, fn state, _source -> String.upcase(state) end
    field :code <- :id
  end
end
