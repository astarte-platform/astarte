#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule AstarteDevToolTest do
  use ExUnit.Case

  @doctest false
  alias AstarteDevTool.Utilities.Auth

  describe "unit test" do
    test "new_ec_private_key/0" do
      assert {:ok, private} = Auth.new_ec_private_key()
    end

    test "public_key_from/1" do
      {:ok, private} = Auth.new_ec_private_key()
      assert {:ok, public} = Auth.public_key_from(private)
    end

    test "pem_keys/0" do
      assert {:ok, {private, public}} = Auth.pem_keys()
    end
  end

  describe "mix tasks" do
    test "auth.keys" do
      {:ok, private} = Mix.Tasks.AstarteDevTool.Auth.Keys.run([])
      {:ok, public} = Mix.Tasks.AstarteDevTool.Auth.Keys.run(["--", private])
    end
  end
end
