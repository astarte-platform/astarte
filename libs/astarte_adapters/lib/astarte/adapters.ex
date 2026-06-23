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
  import the `transform` and `transformp` macros.

  A transformation is defined using `transform` (to generate a public function)
  or `transformp` (to generate a private function). Both take a name for the
  generated function and a `do` block containing the transformation rules.

  ### Mapping Options

  Optional module attributes can be declared at the top of the block:
  * `@source` - The expected input type (defaults to `any()`).
  * `@returns` - The expected output type (defaults to `map()`).

  ### Rules

  Inside a `transform` or `transformp` block, you can use four constructs. They must be declared
  in the following strict order:

  1. `pre_process function`: (Optional) The very first statement. A function of arity 1
      that receives the raw input data and must return a map for the engine to process.
  2. `keep path1, path2, ...`: (Optional) Syntactic sugar for 1-to-1 mappings. Maps
      an arbitrary number of listed keys without modifications. It must appear at most once.
  3. `field`: Defines how to map a field.
      * Standard field: `field :dest <- :source`
      * Standard field with options: `field :dest <- :source, required: false`
      * Computed field (Arity 2): `field :dest <- :source, fn val, source -> ... end, opts`
      * Full source computed field (Arity 1): `field :dest, fn source -> ... end, opts`
  4. `post_process function`: (Optional) The last statement. A function of arity 1
      that will be called with the final mapped structure.

  ## Example

      defmodule MyAdapter do
        use Astarte.Adapters

        @type string_payload :: String.t()

        # Generates a public function `map_payload/1`
        transform map_payload do
          @source string_payload()
          @returns map()

          pre_process &Jason.decode!/1
          keep ["id", "version"]
          field :name <- ["data", "attributes", "name"]
          field :type <- "type", fn type, _source -> String.upcase(type) end, required: false
          field :full_name, fn source -> source["first"] <> " " <> source["last"] end
          post_process &struct!(MyStruct, &1)
        end

        # Generates a private function `private_mapping/1`
        transformp private_mapping do
          field :internal_id <- "id"
          field :timestamp <- "ts"
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
  defmacro transform(name, do: block), do: build_transform(:def, name, block)
  defmacro transformp(name, do: block), do: build_transform(:defp, name, block)

  defp build_transform(def_type, name, block) do
    %{
      pre: pre,
      fields: fields,
      post: post,
      source_type: source_type,
      return_type: return_type
    } = parse_block(block, __ENV__)

    fun_name =
      case name do
        {atom, _, _} when is_atom(atom) -> atom
        atom when is_atom(atom) -> atom
      end

    source_data_var = Macro.var(:source_data, nil)
    processed_source_var = Macro.var(:processed_source, nil)

    pre_ast =
      case pre do
        nil -> quote(do: unquote(processed_source_var) = unquote(source_data_var))
        fun -> quote(do: unquote(processed_source_var) = unquote(fun).(unquote(source_data_var)))
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
        nil -> pipeline
        fun -> quote(do: unquote(fun).(unquote(pipeline)))
      end

    specs =
      case def_type do
        :def ->
          quote do
            @doc "Transforms source data using the `#{unquote(fun_name)}` ruleset."
            @spec unquote(fun_name)(unquote(source_type)) :: unquote(return_type)
          end

        :defp ->
          nil
      end

    quote do
      unquote(specs)

      unquote(def_type)(unquote(fun_name)(unquote(source_data_var))) do
        unquote(pre_ast)
        _ = unquote(processed_source_var)
        unquote(final_ast)
      end
    end
  end

  defp parse_block({:__block__, _, []}, env) do
    raise CompileError,
      file: env.file,
      line: env.line,
      description: "Invalid construct in transform block: nil"
  end

  defp parse_block({:__block__, _, statements}, env), do: parse_statements(statements, env)
  defp parse_block(single_statement, env), do: parse_statements([single_statement], env)

  defp parse_statements(statements, env) do
    result =
      Enum.reduce(
        statements,
        %{
          state: :start,
          pre: nil,
          fields: [],
          post: nil,
          source_type: quote(do: any()),
          return_type: quote(do: %{})
        },
        &reduce_statement(&1, &2, env)
      )

    %{result | fields: Enum.reverse(result.fields)}
  end

  defp reduce_statement({:@, _, [{:source, _, [type]}]}, acc, _env),
    do: %{acc | source_type: type}

  defp reduce_statement({:@, _, [{:returns, _, [type]}]}, acc, _env),
    do: %{acc | return_type: type}

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
       when state in [:start, :pre_process, :keep, :field],
       do: %{acc | state: :field, fields: [parse_field_args(args) | acc.fields]}

  defp reduce_statement({:field, _, _}, %{state: _}, env),
    do:
      raise(CompileError,
        file: env.file,
        line: env.line,
        description: "`field` must appear before `post_process`"
      )

  defp reduce_statement({:post_process, _, [fun]}, %{state: state} = acc, _env)
       when state != :post_process,
       do: %{acc | state: :post_process, post: fun}

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

  defp parse_field_args([{:<-, _, [dest, source]}, func, opts]) when is_list(opts),
    do: {dest, source, Keyword.get(opts, :required, true), func}

  defp parse_field_args([{:<-, _, [dest, source]}, opts]) when is_list(opts),
    do: {dest, source, Keyword.get(opts, :required, true), nil}

  defp parse_field_args([{:<-, _, [dest, source]}, func]), do: {dest, source, true, func}
  defp parse_field_args([{:<-, _, [dest, source]}]), do: {dest, source, true, nil}

  defp parse_field_args([dest, func, opts]) when is_list(opts),
    do: {dest, [], Keyword.get(opts, :required, true), func}

  defp parse_field_args([dest, opts]) when is_list(opts),
    do: {dest, [], Keyword.get(opts, :required, true), nil}

  defp parse_field_args([dest, func]), do: {dest, [], true, func}
  defp parse_field_args([dest]), do: {dest, [], true, nil}

  defp normalize_path(path) when is_atom(path) or is_binary(path), do: [path]
  defp normalize_path(path) when is_list(path), do: path
end
