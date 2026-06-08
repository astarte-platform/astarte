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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.InsertContext do
  @moduledoc false

  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.UUID

  use TypedStruct

  typedstruct do
    field :realm, String.t()
    field :device_id, UUID.t()
    field :interface_descriptor, InterfaceDescriptor.t()
    field :mapping, Mapping.t()
    field :path, String.t()
    field :value, term()
    field :value_timestamp, non_neg_integer()
    field :reception_timestamp, non_neg_integer()
    field :opts, keyword(), default: []
  end
end
