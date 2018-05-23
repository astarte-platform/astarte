#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
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
