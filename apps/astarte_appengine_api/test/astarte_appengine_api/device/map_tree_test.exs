#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.MapTreeTest do
  use ExUnit.Case
  alias Astarte.AppEngine.API.Device.MapTree

  test "inflate a 1 item flat map" do
    flat_map1 = %{
      "this/is/flat" => 42
    }

    expected_inflated1 = %{
      "this" => %{
        "is" => %{
          "flat" => 42
        }
      }
    }

    assert MapTree.inflate_tree(flat_map1) == expected_inflated1
  end

  test "inflate a map with some paths" do
    flat_map2 = %{
      "really/makes/me/think" => "yes",
      "astarte/really/makes/me/think" => "always",
      "something/on/my/path" => 1,
      "something/on/my/value" => 2,
      "something/on/something" => 3,
      "something/value" => 4
    }

    expected_inflated2 = %{
      "really" => %{
        "makes" => %{
          "me" => %{
            "think" => "yes"
          }
        }
      },
      "astarte" => %{
        "really" => %{
          "makes" => %{
            "me" => %{
              "think" => "always"
            }
          }
        }
      },
      "something" => %{
        "on" => %{
          "my" => %{
            "path" => 1,
            "value" => 2
          },
          "something" => 3
        },
        "value" => 4
      }
    }

    assert MapTree.inflate_tree(flat_map2) == expected_inflated2
  end

  test "inflate 1 level map" do
    one_level_map = %{
      "value" => :a_value
    }

    assert MapTree.inflate_tree(one_level_map) == one_level_map
  end
end
