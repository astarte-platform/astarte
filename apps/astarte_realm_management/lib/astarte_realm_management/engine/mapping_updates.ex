# Copyright 2017-2022 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.RealmManagement.Engine.MappingUpdates do
  @moduledoc """
  A struct tracking the updates happening in a minor version update of an interface.

  The `:new` key contains the list of new mappings.
  The `:updated` key contains the list of updated mappings.
  """
  @enforce_keys [:new, :updated]
  defstruct @enforce_keys
end
