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

  use TypedStruct

  typedstruct do
    field :realm, term(), enforce: true
    field :device_id, term(), enforce: true
    field :interface_descriptor, InterfaceDescriptor.t(), enforce: true
    field :mapping, Mapping.t(), enforce: true
    field :path, term(), enforce: true
    field :value, term(), enforce: true
    field :value_timestamp, term(), enforce: true
    field :reception_timestamp, term(), enforce: true
    field :opts, keyword(), default: []
  end
end
