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

defmodule Astarte.AdaptersTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Astarte.Adapters.Generators
  alias Astarte.Adapters.Mappings
  alias Astarte.Adapters.MissingFieldError

  alias Astarte.Adapters.ComplexStruct
  alias Astarte.Adapters.SimpleStruct

  describe "map_to_simple_struct/1" do
    test "transforms complete map" do
      assert %SimpleStruct{id: 1, name: "test"} ==
               Mappings.map_to_simple_struct(%{id: 1, name: "test"})
    end

    test "raises on missing required field" do
      assert_raise MissingFieldError, fn ->
        Mappings.map_to_simple_struct(%{name: "test"})
      end
    end
  end

  describe "map_to_complex_struct/1" do
    test "transforms nested maps" do
      source = %{a: %{id: 42, name: "complex"}, b: [%{id: 1, name: "child1"}]}

      expected = %ComplexStruct{
        id: 42,
        name: "complex",
        children: [%SimpleStruct{id: 1, name: "child1"}]
      }

      assert expected == Mappings.map_to_complex_struct(source)
    end
  end

  describe "complex_struct_to_map/1" do
    test "transforms struct to nested map" do
      source = %ComplexStruct{
        id: 42,
        name: "complex",
        children: [%SimpleStruct{id: 1, name: "child1"}]
      }

      expected = %{a: %{id: 42, name: "complex"}, b: [%{id: 1, name: "child1"}]}

      assert expected == Mappings.complex_struct_to_map(source)
    end

    test "transforms struct omitting optional field" do
      source = %ComplexStruct{
        id: 42,
        name: nil,
        children: []
      }

      expected = %{a: %{id: 42}, b: []}

      assert expected == Mappings.complex_struct_to_map(source)
    end
  end

  describe "string_map_to_string/1" do
    test "concatenates kept fields" do
      assert "helloworld" == Mappings.string_map_to_string(%{"a" => "hello", "b" => "world"})
    end
  end

  describe "full_dsl_test/1" do
    test "applies pre_process, multiple keep, deep path, custom functions, and post_process" do
      source_tuple = {100, "Jane", "Doe", "manager"}

      expected = %{
        id: 100,
        role: "manager",
        is_active: true,
        role_upper: "MANAGER",
        full_name: "Jane Doe",
        processed_at: :now
      }

      assert expected == Mappings.full_dsl_test(source_tuple)
    end
  end

  describe "computed_fields_only/1" do
    test "uses only custom arity 1 functions without source paths" do
      source = %{x: 10, y: 5}
      expected = %{combined: 15, static: "always_this"}

      assert expected == Mappings.computed_fields_only(source)
    end
  end

  describe "mixed_keep_test/1" do
    test "keeps atom and string keys" do
      source = %{"string_key" => 2, atom_key: 1, another_atom: 3, ignore_me: 4}
      expected = %{"string_key" => 2, atom_key: 1, another_atom: 3}

      assert expected == Mappings.mixed_keep_test(source)
    end
  end

  describe "property based tests (generators)" do
    property "map_to_complex_struct/1 maps generated raw data correctly" do
      check all raw_data <- Generators.populate_raw_data() do
        result = Mappings.map_to_complex_struct(raw_data)

        assert %ComplexStruct{} = result
        assert result.id == raw_data.a.id
        assert result.name == raw_data.a.name
        assert length(result.children) == length(raw_data.b)
      end
    end

    property "complex_struct_to_map/1 maps generated tree data correctly" do
      check all tree_data <- Generators.populate_tree_data() do
        result = Mappings.complex_struct_to_map(tree_data)

        assert result.a.id == tree_data.id
        assert result.a.name == tree_data.name
        assert length(result.b) == length(tree_data.children)
      end
    end
  end

  describe "Astarte.Adapters compiler constraints" do
    test "raises if pre_process is not first" do
      code = """
      defmodule TestPreProcessFail do
        use Astarte.Adapters
        transform :fail do
          keep :a
          pre_process fn x -> x end
        end
      end
      """

      assert_raise CompileError, ~r/`pre_process` must be the first statement/, fn ->
        Code.eval_string(code)
      end
    end

    test "raises if keep appears multiple times" do
      code = """
      defmodule TestKeepFail do
        use Astarte.Adapters
        transform :fail do
          keep :a
          keep :b
        end
      end
      """

      assert_raise CompileError, ~r/`keep` must appear at most once/, fn ->
        Code.eval_string(code)
      end
    end

    test "raises if keep appears after field" do
      code = """
      defmodule TestKeepAfterFieldFail do
        use Astarte.Adapters
        transform :fail do
          field :b, :c
          keep :a
        end
      end
      """

      assert_raise CompileError,
                   ~r/`keep` must appear at most once, and before any `field`/,
                   fn ->
                     Code.eval_string(code)
                   end
    end

    test "raises if field appears after post_process" do
      code = """
      defmodule TestFieldAfterPostProcessFail do
        use Astarte.Adapters
        transform :fail do
          post_process fn x -> x end
          field :a, :b
        end
      end
      """

      assert_raise CompileError, ~r/`field` must appear before `post_process`/, fn ->
        Code.eval_string(code)
      end
    end

    test "raises if post_process appears multiple times" do
      code = """
      defmodule TestPostProcessFail do
        use Astarte.Adapters
        transform :fail do
          post_process fn x -> x end
          post_process fn x -> x end
        end
      end
      """

      assert_raise CompileError, ~r/Only one `post_process` is allowed/, fn ->
        Code.eval_string(code)
      end
    end

    test "raises on invalid construct" do
      code = """
      defmodule TestInvalidConstruct do
        use Astarte.Adapters
        transform :fail do
          :invalid_atom
        end
      end
      """

      assert_raise CompileError, ~r/Invalid construct in transform block/, fn ->
        Code.eval_string(code)
      end
    end
  end

  describe "Astarte.Adapters edge cases for 100% coverage" do
    test "keep accepts a list of keys" do
      code = """
      defmodule TestKeepList do
        use Astarte.Adapters
        transform :run do
          keep [:a, :b]
        end
      end
      """

      {{:module, mod, _, _}, _} = Code.eval_string(code)
      assert %{a: 1, b: 2} == mod.run(%{a: 1, b: 2, c: 3})
    end

    test "keep accepts a single key without list" do
      code = """
      defmodule TestKeepSingle do
        use Astarte.Adapters
        transform :run do
          keep :a
        end
      end
      """

      {{:module, mod, _, _}, _} = Code.eval_string(code)
      assert %{a: 1} == mod.run(%{a: 1, b: 2})
    end

    test "computed field without custom function maps the entire source" do
      code = """
      defmodule TestComputedNoCustom do
        use Astarte.Adapters
        transform :run do
          field :a, required: false
        end
      end
      """

      {{:module, mod, _, _}, _} = Code.eval_string(code)
      assert %{a: %{b: 1}} == mod.run(%{b: 1})
    end

    test "empty block returns empty map" do
      code = """
      defmodule TestEmpty do
        use Astarte.Adapters
        transform :run do
        end
      end
      """

      {{:module, mod, _, _}, _} = Code.eval_string(code)
      assert %{} == mod.run(%{a: 1, b: 2})
    end

    test "allows only pre_process" do
      code = """
      defmodule TestPreOnly do
        use Astarte.Adapters
        transform :run do
          pre_process fn x -> %{x: x} end
        end
      end
      """

      {{:module, mod, _, _}, _} = Code.eval_string(code)
      assert %{} == mod.run(1)
    end

    test "allows only post_process" do
      code = """
      defmodule TestPostOnly do
        use Astarte.Adapters
        transform :run do
          post_process fn x -> Map.put(x, :ok, true) end
        end
      end
      """

      {{:module, mod, _, _}, _} = Code.eval_string(code)
      assert %{ok: true} == mod.run(%{})
    end
  end

  describe "Astarte.Adapters.Engine runtime constraints" do
    test "raises ArgumentError when custom option is invalid" do
      code = """
      defmodule TestRuntimeArity do
        use Astarte.Adapters
        transform :run do
          field :a, :b, custom: "not a function"
        end
      end
      """

      {{:module, mod, _, _}, _} = Code.eval_string(code)

      assert_raise ArgumentError, ~r/Invalid :custom option for field :a/, fn ->
        mod.run(%{b: 1})
      end
    end
  end
end
