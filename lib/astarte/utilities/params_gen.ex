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
  - **Labeled Clauses:** Bind overrides to a specific clause using labels to avoid conflicts and improve readability.

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

  ### Labeling a clause for overrides

  Labels let you target a specific clause for overrides via `params:`. This is useful when the left side is a pattern (not a single variable), or when you want explicit names.

  Supported form:

  - Leading atom label:

      params gen all :payload, var <- integer(), params: [payload: 42] do
        v
      end

  With labels, the override uses the label name (e.g., `:payload`) instead of a variable name (e.g., `var`).

  ### Destructuring with labels

  `params gen all` supports destructuring on the left-hand side only in labeled clauses. Use the label as the hook name for the override.

      params gen all :var,
                     %{b: b} = var <- string(?a..?a, length: 1),
                     params: [var: %{b: 10}] do
        {b, var}
      end

  In the example above, the `:var` label is the hook, so `params: [var: %{b: 10}]` overrides the generator for that clause; `b` will be `10` and `var` will be `%{b: 10}`.

  ## Notes

  - **Integration with ExUnitProperties:** This macro leverages the existing functionality of ExUnitProperties,
    making it easy to adopt if you are already using property-based testing in your project.
  - **Macro Syntax:** The macro expects a keyword list under the `params:` key, where each key corresponds to
    a generator name (e.g., `a`, `b`) or a clause label (e.g., `:payload`). For destructured clauses, a label is mandatory and is used as the hook name. Each value is the custom generator or fixed params to be used.
  - **Fallback Behavior:** For generators not specified in the override list, the macro will default to using
    the original generator from ExUnitProperties.
  - **Compile-Time Verification:** Misuse or incorrect configuration will be flagged at compile time, helping
    you catch errors early in the development process.

  """

  @ignore_token :_

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
  - Destructuring: with patterns like `%{k: v} <- ...`, a label is mandatory; the label is the hook.
  - Label: you can label a clause by placing a leading atom (e.g., `:payload`).
  - Precedence: if both a variable and a `:label` are present, the label wins.
  - Ignore override: label a clause with `:_` to explicitly opt-out from overrides for that clause.

  Examples

      # Override by variable name
      params gen all a <- integer(),
                     params: [a: constant(10)] do
        a
      end
  syntax parity with `gen all`.
      # Destructuring: label is mandatory and acts as the hook
      params gen all :var,
  - Destructuring: with patterns like `%{k: v} <- ...`, a label is mandatory; the label is the hook.
                     params: [var: %{b: 10}] do
        {b, var}
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

  @doc false
  @type stream() :: StreamData.t(term())
  @spec gen_param(stream(), atom(), keyword()) :: stream()
  def gen_param(default_gen, param_name, params) do
    if param_ignore_token?(params) do
      raise ArgumentError, "Cannot use :_ as key into the params keyword list."
    end

    case Keyword.fetch(params, param_name) do
      {:ok, value} ->
        if(stream_data?(value), do: value, else: StreamData.constant(value))

      :error ->
        default_gen
    end
  end

  defp override({:<-, meta, [{var, var_meta, other}, default_gen]}, param, params) do
    gen_param_quoted =
      quote do
        gen_param(unquote(default_gen), unquote(param), unquote(params))
      end

    {:<-, meta,
     [
       {var, var_meta, other},
       gen_param_quoted
     ]}
  end

  defp edit_clause([clause | tail], param, params, acc) do
    clause = override(clause, param, params)
    compile_clauses(tail, params, [clause | acc])
  end

  defp compile_clauses([], _, acc), do: acc

  defp compile_clauses(
         [label, {:<-, _, [{:=, _, _}, _]} = clause | tail],
         params,
         acc
       )
       when is_atom(label),
       do: edit_clause([clause | tail], label, params, acc)

  defp compile_clauses([label, {:<-, _, [{_param, _, _}, _]} = clause | tail], params, acc)
       when is_atom(label),
       do: edit_clause([clause | tail], label, params, acc)

  defp compile_clauses(
         [{:<-, meta, [{:=, _, _}, _]} | _tail],
         _params,
         _acc
       ) do
    line = Keyword.get(meta, :line)

    raise CompileError,
      line: line,
      description: "To use destructuring within `params gen all`, :label(s) are mandatory."
  end

  defp compile_clauses([{:<-, _, [{param, _, _}, _]} = clause | tail], params, acc),
    do: edit_clause([clause | tail], param, params, acc)

  defp compile_clauses([{:=, _, _} = clause | tail], params, acc),
    do: compile_clauses(tail, params, [clause | acc])

  defp split_clauses_and_params(clauses_and_params) do
    case Enum.split_while(clauses_and_params, &(not Keyword.keyword?(&1))) do
      {_clauses, []} = result -> result
      {clauses, [params]} -> {clauses, Keyword.fetch!(params, :params)}
    end
  end

  defp param_ignore_token?(params) when is_list(params),
    do: Keyword.has_key?(params, @ignore_token)

  defp param_ignore_token?(_), do: false

  defp compile(clauses_and_params, body) do
    {clauses, params} = split_clauses_and_params(clauses_and_params)

    if param_ignore_token?(params),
      do:
        raise(CompileError,
          description: "Cannot use :_ as key into the params keyword list."
        )

    clauses =
      compile_clauses(clauses, params, [])
      |> Enum.reverse()

    quote do
      gen all(unquote_splicing(clauses)) do
        var!(generated_values, unquote(__MODULE__)) = []
        unquote(body)
      end
    end
  end
end
