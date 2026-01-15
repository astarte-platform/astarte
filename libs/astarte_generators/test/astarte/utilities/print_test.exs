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

defmodule Astarte.Generators.UtilitiesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Generators.Utilities

  @moduletag :print
  @moduletag :fans

  defp gen_list_fixtures(_context),
    do: {:ok, gen_list: [string(:printable), integer(), byte()]}

  defp pre_post_list_fixtures(_context),
    do: {:ok, pre_post_list: [nil, "", "ok", :ok, 2, true]}

  setup_all [:gen_list_fixtures, :pre_post_list_fixtures]

  @doc false
  describe "print/2 utility" do
    @describetag :success
    @describetag :ut

    property "valid without pre/post", %{gen_list: gen_list} do
      for gen <- gen_list do
        check all s <- Utilities.print(gen) do
          assert is_binary(s)
        end
      end
    end

    property "valid with :pre", %{gen_list: gen_list, pre_post_list: pre_post_list} do
      for pre <- pre_post_list do
        check_pre = "#{pre}"

        for gen <- gen_list do
          check all s <- Utilities.print(gen, pre: pre) do
            assert String.starts_with?(s, check_pre)
          end
        end
      end
    end

    property "valid with :post", %{gen_list: gen_list, pre_post_list: pre_post_list} do
      for post <- pre_post_list do
        check_post = "#{post}"

        for gen <- gen_list do
          check all s <- Utilities.print(gen, post: post) do
            assert String.ends_with?(s, check_post)
          end
        end
      end
    end
  end
end
