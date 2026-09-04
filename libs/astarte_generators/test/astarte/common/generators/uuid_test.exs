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

defmodule Astarte.Common.Generators.UUIDTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Common.Generators.UUID

  @moduletag :common
  @moduletag :uuid

  describe "UUID generator" do
    property "generates RFC 4122 version 4 UUIDs" do
      check all uuid <- uuid() do
        <<_prefix::48, version::4, _middle::12, variant::2, _suffix::62>> = uuid

        assert byte_size(uuid) == 16 and version == 4 and variant == 2
      end
    end
  end
end
