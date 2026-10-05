#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Generators.Utilities.ParamsGen do
  @moduledoc """
  The `params gen all` macro is an enhanced version of ExUnitProperties’s `gen all` macro,
  designed to provide a flexible way to override default generators.

  ## Overview

  `params gen all` extends the capabilities of the standard `gen all` macro by allowing
  developers to substitute default generators with custom ones. This is particularly useful when
  you need to enforce specific constraints on generated data or tailor test inputs to match domain-specific requirements.

  ## Features

  - **Overriding Capability:** Easily override one or more default generators with custom generators.
  - **Seamless Integration:** Built on top of ExUnitProperties, it integrates smoothly with your property-based tests.
  - **Flexible Customization:** Accepts a keyword list for generator overrides, ensuring that only the generators you specify are replaced while the rest remain untouched.
  - **Improved Test Clarity:** By explicitly defining custom generators, tests become easier to understand and maintain.
  - **Targeted opt-out:** Use the `exclude` option to keep specific generators untouched even when overrides are provided.

  ## Usage Examples

  ### Example

  In this example, we override the default `a` integer generator with a generator that picks from [2, 3, 4].

  defmodule MyGenerators do
    use Astarte.Generators.Utilities.ParamsGen

    # Override the default integer generator using params gen all
    def parametric_generators(params \\ [a: member_of([2, 3, 4])])
    params gen all a <- integer(),
                   b <- list_of(string(:ascii)),
                   c <- constant({:atom, "string"}),
                   params: params do
        {a, b, c}
      end
  end

  ### Ignoring overrides with `exclude`

  When you need to prevent a clause from being overridden, add it to the `exclude` option.

      params gen all a <- integer(),
                     topic <- string(:alphanumeric),
                     params: [a: constant(5), topic: constant("foo")],
                     exclude: [:topic] do
        {a, topic}
      end

  In the example above, `a` is overridden, while `topic` uses the default generator despite being present in `params`.

  ## Notes

  - **Integration with ExUnitProperties:** This macro leverages the existing functionality of ExUnitProperties,
    making it easy to adopt if you are already using property-based testing in your project.
  - **Macro Syntax:** The macro expects a keyword list under the `params:` key, where each key corresponds to
    a generator name (e.g., `a`, `b`). Each value is the custom generator or fixed params to be used.
  - **Fallback Behavior:** For generators not specified in the override list, the macro will default to using
    the original generator from ExUnitProperties.
  - **Compile-Time Verification:** Misuse or incorrect configuration will be flagged at compile time, helping
    you catch errors early in the development process.
  - **Mutual Exclusivity:** The same hook cannot appear in both `params:` and `exclude:`—this configuration raises at compile-time (and at runtime if `gen_param/4` is called directly).

  """
  @doc """
  Injects the necessary imports to use ParamsGen functionalities.
  This macro brings in the current module, StreamData, and ExUnitProperties, which are required for property-based tests with custom generator overrides.
  """
  @spec __using__(opts :: any()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      import StreamData
      import ExUnitProperties
    end
  end

  @doc """
  Macro `params gen all` with targeted generator overrides.

  Accepts a `params:` keyword list to override default generators or values, while keeping full
  syntax parity with `gen all`.

  - Hook: for simple clauses, the hook is the variable name on the left of `<-`.
  - Hooks are always the variable names on the left of `<-`.
  - Destructuring patterns are treated as opaque and cannot be overridden directly.
  - Use the `exclude` option to explicitly opt out from overrides for selected hooks.

  Examples

      # Override by variable name
      params gen all a <- integer(),
                     params: [a: constant(10)] do
        a
      end
  syntax parity with `gen all`.

      # Keep the default generator for :topic even if overrides are provided
      params gen all topic <- string(:alphanumeric),
                     params: [topic: constant("should not win")],
                     exclude: [:topic] do
        topic
      end

  """
  @spec params({:gen, any(), [{:all, any(), list()}]}, [{:do, any()}]) :: Macro.t()
  defmacro params({:gen, _gen_meta, [{:all, _all_meta, clauses}]}, do: body) do
    compile(clauses, body)
  end

  defp stream_data?(term) when is_atom(term), do: true
  defp stream_data?(term) when is_tuple(term), do: true
  defp stream_data?(%StreamData{} = _term), do: true
  defp stream_data?(_), do: false

  defp overlapping_hooks(params, exclude) when is_list(params) and is_list(exclude) do
    exclude_set = MapSet.new(exclude)

    params
    |> Keyword.keys()
    |> Enum.filter(&MapSet.member?(exclude_set, &1))
  end

  defp overlapping_hooks(_params, _exclude), do: []

  defp compile_time_conflict!(params, exclude) do
    case overlapping_hooks(params, exclude) do
      [] ->
        :ok

      conflicts ->
        formatted = conflicts |> Enum.map_join(", ", &inspect/1)

        raise CompileError,
          description:
            "Cannot configure both `params:` and `exclude:` for the same hook(s): #{formatted}."
    end
  end

  defp runtime_conflict!(param, params, exclude)
       when is_list(params) and is_list(exclude) do
    if Keyword.has_key?(params, param) and Enum.member?(exclude, param) do
      raise RuntimeError,
            "Cannot override #{inspect(param)} because it is listed under `exclude:`."
    end
  end

  @doc false
  @type stream() :: StreamData.t(term())
  @spec gen_param(stream(), atom(), keyword(), [atom()]) :: stream()
  def gen_param(default_gen, param_name, params, exclude \\ []) do
    runtime_conflict!(param_name, params, exclude)

    case Keyword.fetch(params, param_name) do
      {:ok, value} -> if(stream_data?(value), do: value, else: StreamData.constant(value))
      :error -> default_gen
    end
  end

  defp override({{:<-, meta, [{var, var_meta, other}, default_gen]}, param, params, exclude}) do
    gen_param_quoted =
      quote do
        gen_param(unquote(default_gen), unquote(param), unquote(params), unquote(exclude))
      end

    {:<-, meta,
     [
       {var, var_meta, other},
       gen_param_quoted
     ]}
  end

  defp edit_clause({[clause | tail], param, params, exclude, acc}) do
    clause = override({clause, param, params, exclude})
    compile_clauses({tail, params, exclude, [clause | acc]})
  end

  defp compile_clauses({[], _, _, acc}), do: acc

  defp compile_clauses({[label | _], _params, _exclude, _acc}) when is_atom(label) do
    raise CompileError,
      description:
        "`params gen all` no longer supports leading clause labels. Remove atoms such as #{inspect(label)} and rely on hooks or `exclude:`."
  end

  defp compile_clauses({[{:<-, meta, [{:=, _, _}, _]} | _tail], _params, _exclude, _acc}) do
    line = Keyword.get(meta, :line)

    raise CompileError,
      line: line,
      description: "`params gen all` cannot handle assignments within a generation."
  end

  defp compile_clauses({[{:<-, _, [{param, _, _}, _]} = clause | tail], params, exclude, acc}),
    do: edit_clause({[clause | tail], param, params, exclude, acc})

  defp compile_clauses({[{:=, _, _} = clause | tail], params, exclude, acc}),
    do: compile_clauses({tail, params, exclude, [clause | acc]})

  defp split_clauses_params_exclude(clauses_params_exclude) do
    case Enum.split_while(clauses_params_exclude, &(not Keyword.keyword?(&1))) do
      {clauses, []} ->
        {clauses, [], []}

      {clauses, [params_and_exclude]} ->
        params = Keyword.fetch!(params_and_exclude, :params)

        exclude =
          if Keyword.has_key?(params_and_exclude, :exclude),
            do: Keyword.fetch!(params_and_exclude, :exclude),
            else: []

        if Keyword.keyword?(params) do
          compile_time_conflict!(params, exclude)
        end

        {clauses, params, exclude}
    end
  end

  defp compile(clauses_params_exclude, body) do
    {clauses, params, exclude} = split_clauses_params_exclude(clauses_params_exclude)

    clauses =
      compile_clauses({clauses, params, exclude, []})
      |> Enum.reverse()

    quote do
      gen all(unquote_splicing(clauses)) do
        var!(generated_values, unquote(__MODULE__)) = []
        unquote(body)
      end
    end
  end
end
