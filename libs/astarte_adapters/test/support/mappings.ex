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

  transform :map_to_simple_struct, returns: SimpleStruct.t() do
    field :id, :id
    field :name, :name, required: false
    post_process &struct!(SimpleStruct, &1)
  end

  @type my_source :: %{a: %{id: integer(), name: String.t() | nil}, b: [map()]}
  transform :map_to_complex_struct, source: my_source(), returns: ComplexStruct.t() do
    field :id, [:a, :id]
    field :name, [:a, :name], required: false

    field :children, :b,
      custom: fn children, _source ->
        Enum.map(children, &map_to_simple_struct/1)
      end

    post_process &struct!(ComplexStruct, &1)
  end

  transform :complex_struct_to_map do
    field [:a, :id], :id
    field [:a, :name], :name, required: false

    field :b, :children,
      custom: fn children, _source ->
        Enum.map(children, &Map.from_struct/1)
      end
  end

  @type string_source :: %{
          required(String.t()) => String.t(),
          required(String.t()) => String.t()
        }
  @type string_result :: String.t()
  transform :string_map_to_string, source: string_source(), returns: string_result() do
    keep "a", "b"
    post_process fn %{"a" => a, "b" => b} -> a <> b end
  end

  transform :full_dsl_test do
    pre_process fn {id, first, last, role} ->
      %{id: id, first: first, last: last, role: role, meta: %{active: true}}
    end

    keep :id, :role
    field :is_active, [:meta, :active]
    field :role_upper, :role, custom: fn role, _source -> String.upcase(role) end
    field :full_name, custom: fn source -> "#{source.first} #{source.last}" end
    post_process fn result -> Map.put(result, :processed_at, :now) end
  end

  transform :computed_fields_only do
    field :combined, custom: fn src -> src.x + src.y end
    field :static, custom: fn _src -> "always_this" end
  end

  transform :mixed_keep_test do
    keep :atom_key, "string_key", :another_atom
  end
end
