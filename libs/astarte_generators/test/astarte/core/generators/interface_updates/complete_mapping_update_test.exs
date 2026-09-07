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

defmodule Astarte.Core.Generators.InterfaceUpdates.CompleteMappingUpdateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.InterfaceUpdateTest.Support
  import Astarte.Core.Generators.InterfaceUpdates.CompleteMappingUpdate

  describe "complete interface update generator" do
    property "generates complete represented updates" do
      check all interface <- interface(aggregation: :object),
                api_update <- valid_complete_mapping_update_for(interface, :api),
                database_update <- valid_complete_mapping_update_for(interface, :database) do
        assert valid_update?(interface, api_update, :api) and
                 valid_update?(interface, database_update, :database) and
                 complete_object_update?(interface, api_update) and
                 complete_object_update?(interface, database_update)
      end
    end
  end
end
