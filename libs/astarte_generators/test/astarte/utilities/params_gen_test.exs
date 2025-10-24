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

defmodule Astarte.Generators.Utilities.ParamsGenTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Astarte.Generators.Utilities.ParamsGen

  @moduletag :params
  @moduletag :fans

  # Utilities

  defp gen_base do
    gen all a <- integer(0..0),
            b <- string(?a..?a, length: 1),
            c <- constant("friend") do
      {a, b, c}
    end
  end

  defp params_gen(params) do
    params gen all a <- integer(0..0),
                   b <- string(?a..?a, length: 1),
                   c <- constant("friend"),
                   params: params do
      {a, b, c}
    end
  end

  defp params_gen_eq(params) do
    params gen all a <- integer(0..0),
                   {:ok, 0} = {:ok, a},
                   a1 = a,
                   b <- string(?a..?a, length: 1),
                   b1 = b,
                   c <- constant("friend"),
                   c1 = c,
                   params: params do
      {a1, b1, c1}
    end
  end

  defp params_gen_label(params) do
    params gen all a <- integer(0..0),
                   :b,
                   var <- string(?a..?a, length: 1),
                   c <- constant("friend"),
                   params: params do
      {a, var, c}
    end
  end

  defp params_gen_label_destruct do
    params gen all a <- integer(0..0),
                   :b,
                   %{b: b} = not_hooked <- string(?a..?a, length: 1),
                   c <- constant("friend"),
                   params: [b: %{b: 10}] do
      {a, b, c, not_hooked}
    end
  end

  defp params_gen_label_ignore do
    params gen all :_,
                   a <- integer(0..0),
                   :_,
                   b = b_1 = b_2 <- string(?a..?a, length: 1),
                   :_,
                   c <- constant("friend"),
                   params: [a: "never", b: "never", c: "never"] do
      {a, b, b_1, b_2, c}
    end
  end

  defp params_gen_no_params do
    params gen all a <- integer(0..0),
                   b <- string(?a..?a, length: 1),
                   c <- constant("friend") do
      {a, b, c}
    end
  end

  # Params
  defp gen_params do
    gen all a <- integer(),
            b <- string(:ascii) do
      [a: a, b: b]
    end
  end

  defp function_params(b), do: [a: 10, b: %{b: b}]

  @doc false
  describe "gen_param unit tests" do
    @describetag :success
    @describetag :ut

    test "gen_param accepts atom constant override" do
      assert :ok = gen_param(gen_base(), :value, value: :ok)
    end

    test "gen_param accepts tuple constant override" do
      assert {0, 1} = gen_param(gen_base(), :value, value: {0, 1})
    end

    test "gen_param passes through tuple of generators unchanged (for advanced composition)" do
      assert {%StreamData{}, %StreamData{}} =
               gen_param(gen_base(), :value, value: {integer(), string(:alphanumeric)})
    end

    test "gen_param raises when runtime params include :_" do
      assert_raise ArgumentError,
                   "Cannot use :_ as key into the params keyword list.",
                   fn -> gen_param(gen_base(), :_, _: constant("never")) end
    end

    property "gen_param does not intervene" do
      check all {a, b, c} <- gen_param(gen_base(), :value, other_value: "a"), max_runs: 1 do
        assert a == 0
        assert b == "a"
        assert c == "friend"
      end
    end

    property "gen_param constant override" do
      check all value <- gen_param(gen_base(), :value, value: "a"), max_runs: 1 do
        assert value == "a"
      end
    end

    property "gen_param function override" do
      check all value <- gen_param(gen_base(), :value, value: function_params("a")), max_runs: 1 do
        assert [a: 10, b: %{b: "a"}] == value
      end
    end

    property "gen_param generator override" do
      check all [
                  a: int_value,
                  b: string_value
                ] <- gen_param(gen_base(), :value, value: gen_params()),
                max_runs: 1 do
        assert is_integer(int_value) and is_binary(string_value)
      end
    end
  end

  @doc false
  describe "param gen all unit tests" do
    @describetag :success
    @describetag :ut

    property "gen all parity features (without override)" do
      check all {a1, b1, c1} <- gen_base(),
                {a2, b2, c2} <- params_gen([]),
                max_runs: 1 do
        assert a1 == a2
        assert b1 == b2
        assert c1 == c2
      end
    end

    property "param gen all without params option behaves like gen all" do
      check all {a1, b1, c1} <- gen_base(),
                {a2, b2, c2} <- params_gen_no_params(),
                max_runs: 1 do
        assert a1 == a2
        assert b1 == b2
        assert c1 == c2
      end
    end

    @tag :issue
    property "param gen all does not crash using = op" do
      check all {a1, b1, c1} <- gen_base(),
                {a2, b2, c2} <- params_gen_eq([]),
                max_runs: 1 do
        assert a1 == a2
        assert b1 == b2
        assert c1 == c2
      end
    end

    property "param gen all overridden by kw" do
      check all params <- gen_params(), {a, b, _} <- params_gen(params), max_runs: 1 do
        assert params[:a] == a
        assert params[:b] == b
      end
    end

    property "param gen all overridden by generators" do
      check all {a, _, _} <- params_gen(a: string(?c..?c, length: 1)), max_runs: 1 do
        assert a == "c"
      end
    end

    property "param gen all overridden by function" do
      check all s <- integer(10..10),
                {a, b, _} <- params_gen(function_params(s)),
                max_runs: 1 do
        assert a == 10
        assert b == %{b: 10}
      end
    end

    property "param gen all overridden by static value for c" do
      check all string_value <- string(:utf8),
                {_, _, c} <- params_gen(c: string_value),
                max_runs: 1 do
        assert c == string_value
      end
    end

    property "param gen all override use :label instead variable name when is using pattern matching" do
      check all {a, b, c} <- params_gen_label(b: 10), max_runs: 1 do
        assert a == 0
        assert b == 10
        assert c == "friend"
      end
    end

    property "param gen all override by :label wins over var name" do
      check all {a, b, c, not_changed} <- params_gen_label_destruct(), max_runs: 1 do
        assert a == 0
        assert b == 10
        assert c == "friend"
        assert %{b: 10} = not_changed
      end
    end

    property "param gen all override by 'ignore_token' (`:_`) does nothing" do
      check all {a, b, b_1, b_2, c} <- params_gen_label_ignore(), max_runs: 1 do
        assert a == 0
        assert b == "a"
        assert b_1 == "a"
        assert b_2 == "a"
        assert c == "friend"
      end
    end
  end
end
