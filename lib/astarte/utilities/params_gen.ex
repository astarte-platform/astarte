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

  ## Usage Examples

  ### Example

  In this example, we override the default `a` integer generator with a tuple {2, 3, 4}.

  defmodule MyGenerators do
    use Astarte.Generators.Utilities.ParamsGen

    # Override the default integer generator using params gen all
    def parametric_generators(params \\ [a: { 2, 3, 4}])
    params gen(
      all a <- integer(),
          b <- list_of(string(:ascii)),
          c <- constant({:amicizia, "dottore"}),
          params: params
    ) do
        {a, b, c}
      end
  end

  ## Notes

  - **Integration with ExUnitProperties:** This macro leverages the existing functionality of ExUnitProperties,
    making it easy to adopt if you are already using property-based testing in your project.
  - **Macro Syntax:** The macro expects a keyword list under the `params:` key, where each key corresponds to
    a generator name (e.g., `a`, `b`) and each value is the custom generator or fixed params to be used.
  - **Fallback Behavior:** For generators not specified in the override list, the macro will default to using
    the original generator from ExUnitProperties.
  - **Compile-Time Verification:** Misuse or incorrect configuration will be flagged at compile time, helping
    you catch errors early in the development process.

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

  @doc false
  @spec params({:gen, any(), [{:all, any(), any()}]}) :: Macro.t()
  defmacro params({:gen, _gen_meta, [{:all, _all_meta, clauses_with_body}]}) do
    {clauses, [[do: body]]} = Enum.split(clauses_with_body, -1)
    compile(clauses, body)
  end

  @doc """
  Defines a custom property-based test generator macro (`params gen all`) that supports overriding default generators.
  It processes generator clauses and applies any custom overrides provided via the `:params` keyword.
  """
  @spec params({:gen, any(), [{:all, any(), list()}]}, [{:do, any()}]) :: Macro.t()
  defmacro params({:gen, _gen_meta, [{:all, _all_meta, clauses}]}, do: body) do
    compile(clauses, body)
  end

  defp stream_data?(%StreamData{} = _term), do: true
  defp stream_data?({%StreamData{}, %StreamData{}} = _term), do: true
  defp stream_data?(_), do: false

  @doc """
  Function called from the macro, to wrap generators
  """
  @type stream() :: StreamData.t(term())
  @spec gen_param(stream(), atom(), keyword()) :: stream()
  def gen_param(default_gen, param_name, params) do
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

  defp compile_clauses([], _, acc), do: acc

  defp compile_clauses([{:<-, _, [{param, _, _}, _]} = clause | tail], params, acc) do
    clause = override(clause, param, params)
    compile_clauses(tail, params, [clause | acc])
  end

  defp compile_clauses(clauses, params), do: compile_clauses(clauses, params, [])

  defp split_clauses_and_params(clauses_and_params) do
    case Enum.split_while(clauses_and_params, &(not Keyword.keyword?(&1))) do
      {_clauses, []} = result -> result
      {clauses, [params]} -> {clauses, Keyword.fetch!(params, :params)}
    end
  end

  defp compile(clauses_and_params, body) do
    {clauses, params} = split_clauses_and_params(clauses_and_params)

    clauses =
      compile_clauses(clauses, params)
      |> Enum.reverse()

    quote do
      gen all(unquote_splicing(clauses)) do
        var!(generated_values, unquote(__MODULE__)) = []
        unquote(body)
      end
    end
  end
end
