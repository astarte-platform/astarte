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

defmodule Astarte.Auth.Config.OpenFGAStoreBindingTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Auth.Config
  alias Astarte.Auth.Config.OpenFGAStoreBinding
  alias Astarte.Auth.OpenFGA

  describe "get_env/2" do
    test "looks the store id up by the configured store name" do
      stub(Config, :openfga_store_name, fn -> {:ok, "astarte"} end)
      expect(OpenFGA, :fetch_store_id, fn "astarte" -> {:ok, "01FOUND"} end)

      assert OpenFGAStoreBinding.get_env(nil, nil) == {:ok, "01FOUND"}
    end

    test "resolves nothing when no store name is configured" do
      reject(&OpenFGA.fetch_store_id/1)

      for unset <- [nil, ""] do
        stub(Config, :openfga_store_name, fn -> {:ok, unset} end)

        assert OpenFGAStoreBinding.get_env(nil, nil) == {:ok, nil}
      end
    end

    test "reports why the named store can't be found" do
      stub(Config, :openfga_store_name, fn -> {:ok, "astarte"} end)

      for reason <- [:not_found, :ambiguous, :econnrefused] do
        expect(OpenFGA, :fetch_store_id, fn "astarte" -> {:error, reason} end)

        assert OpenFGAStoreBinding.get_env(nil, nil) == {:error, reason}
      end
    end
  end
end
