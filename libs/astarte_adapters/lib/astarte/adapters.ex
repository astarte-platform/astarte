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

defmodule Astarte.Adapters do
  @moduledoc ~S"""
  Provides a declarative DSL for deep map/struct transformations.

  This module allows defining complex mappings between nested data structures
  (like maps or structs) in a declarative way. It is useful for adapting
  data from one format to another, for example, from an external API payload
  to an internal Ecto schema.

  ## Usage

  To use the DSL, you must `use Astarte.Adapters` in your module. This will
  import the `transform` macro.

  A transformation is defined using `transform`, which takes a name for the generated
  function, an optional keyword list of configuration options, and a `do` block containing
  the transformation rules.

  ### Mapping Options

  * `:source` - The expected input type (defaults to `any()`).
  * `:returns` - The expected output type (defaults to `map()`).

  ### Rules

  Inside a `transform` block, you can use four constructs. They must be declared
  in the following strict order:

  1. `pre_process function`: (Optional) The very first statement. A function of arity 1
      that receives the raw input data and must return a map for the engine to process.
  2. `keep path1, path2, ...`: (Optional) Syntactic sugar for 1-to-1 mappings. Maps
      an arbitrary number of listed keys without modifications. It must appear at most once.
  3. `field destination, source, options`: Defines how to map a field.
      * Standard field: `field :dest, :source, opts`
      * Computed field: `field :dest, custom: fn source -> ... end`
  4. `post_process function`: (Optional) The last statement. A function of arity 1
      that will be called with the final mapped structure.

  ## Example

      defmodule MyAdapter do
        use Astarte.Adapters

        @type string_payload :: String.t()

        transform :json_to_struct, source: string_payload() do
          pre_process &Jason.decode!/1
          keep "id", "version"
          field :name, ["data", "attributes", "name"]
          field :type, "type", custom: fn type, _source -> String.upcase(type) end
          field :full_name, custom: fn source -> source["first"] <> " " <> source["last"] end
          post_process &struct!(MyStruct, &1)
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Astarte.Adapters
      import Astarte.Adapters.Engine
    end
  end

  @doc """
  Defines a transformation ruleset.
  """
  defmacro transform(name, opts \\ [], do: block) do
    source_type = Keyword.get(opts, :source, quote(do: any()))
    return_type = Keyword.get(opts, :returns, quote(do: map()))

    %{pre: pre, fields: fields, post: post} = parse_block(block, __ENV__)

    source_data_var = Macro.var(:source_data, nil)
    processed_source_var = Macro.var(:processed_source, nil)

    pre_ast =
      case pre do
        nil ->
          quote do
            unquote(processed_source_var) = unquote(source_data_var)
          end

        fun ->
          quote do
            unquote(processed_source_var) = unquote(fun).(unquote(source_data_var))
          end
      end

    pipeline =
      Enum.reduce(fields, quote(do: %{}), fn {dest, source, required, custom_fun}, acc ->
        dest_path = normalize_path(dest)
        source_path = normalize_path(source)
        dest_field_name = List.last(dest_path)

        quote do
          process_field(
            unquote(acc),
            unquote(processed_source_var),
            unquote(dest_path),
            unquote(source_path),
            unquote(dest_field_name),
            unquote(required),
            unquote(custom_fun)
          )
        end
      end)

    final_ast =
      case post do
        nil ->
          pipeline

        fun ->
          quote do
            unquote(fun).(unquote(pipeline))
          end
      end

    quote do
      @doc "Transforms source data using the `#{unquote(name)}` ruleset."
      @spec unquote(name)(unquote(source_type)) :: unquote(return_type)
      def unquote(name)(unquote(source_data_var)) do
        unquote(pre_ast)
        _ = unquote(processed_source_var)
        unquote(final_ast)
      end
    end
  end

  defp parse_block({:__block__, _, statements}, env), do: parse_statements(statements, env)
  defp parse_block(single_statement, env), do: parse_statements([single_statement], env)

  defp parse_statements(statements, env) do
    result =
      Enum.reduce(
        statements,
        %{state: :start, pre: nil, fields: [], post: nil},
        &reduce_statement(&1, &2, env)
      )

    %{result | fields: Enum.reverse(result.fields)}
  end

  defp reduce_statement({:pre_process, _, [fun]}, %{state: :start} = acc, _env),
    do: %{acc | state: :pre_process, pre: fun}

  defp reduce_statement({:pre_process, _, _}, %{state: _}, env),
    do:
      raise(CompileError,
        file: env.file,
        line: env.line,
        description: "`pre_process` must be the first statement"
      )

  defp reduce_statement({:keep, _, args}, %{state: state} = acc, _env)
       when state in [:start, :pre_process] do
    keys =
      case args do
        [list] when is_list(list) -> list
        other -> other
      end

    keep_fields = Enum.map(keys, fn key -> {key, key, true, nil} end)
    %{acc | state: :keep, fields: keep_fields ++ acc.fields}
  end

  defp reduce_statement({:keep, _, _}, %{state: _}, env),
    do:
      raise(CompileError,
        file: env.file,
        line: env.line,
        description: "`keep` must appear at most once, and before any `field`"
      )

  defp reduce_statement({:field, _, args}, %{state: state} = acc, _env)
       when state in [:start, :pre_process, :keep, :field] do
    %{acc | state: :field, fields: [parse_field_args(args) | acc.fields]}
  end

  defp reduce_statement({:field, _, _}, %{state: _}, env),
    do:
      raise(CompileError,
        file: env.file,
        line: env.line,
        description: "`field` must appear before `post_process`"
      )

  defp reduce_statement({:post_process, _, [fun]}, %{state: state} = acc, _env)
       when state != :post_process do
    %{acc | state: :post_process, post: fun}
  end

  defp reduce_statement({:post_process, _, _}, %{state: _}, env),
    do:
      raise(CompileError,
        file: env.file,
        line: env.line,
        description: "Only one `post_process` is allowed"
      )

  defp reduce_statement(invalid_node, %{state: _}, env),
    do:
      raise(CompileError,
        file: env.file,
        line: env.line,
        description: "Invalid construct in transform block: #{inspect(invalid_node)}"
      )

  defp parse_field_args([dest, [{key, _} | _] = opts]) when is_atom(key) do
    adapted_fun =
      case Keyword.get(opts, :custom) do
        nil -> nil
        fun -> quote do: fn _val, source -> unquote(fun).(source) end
      end

    {dest, [], false, adapted_fun}
  end

  defp parse_field_args([dest, source]) do
    {dest, source, true, nil}
  end

  defp parse_field_args([dest, source, opts]) when is_list(opts) do
    {dest, source, Keyword.get(opts, :required, true), Keyword.get(opts, :custom)}
  end

  defp normalize_path(path) when is_atom(path) or is_binary(path), do: [path]
  defp normalize_path(path) when is_list(path), do: path
end
