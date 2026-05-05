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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.Core.Device.CapabilitiesTest do
  use ExUnit.Case

  alias Astarte.Core.Device.Capabilities

  test "capabilities with :purge_properties_compression_format :zlib" do
    params = %{
      "purge_properties_compression_format" => "zlib"
    }

    changeset = Capabilities.changeset(%Capabilities{}, params)

    assert %Ecto.Changeset{valid?: true} = changeset

    {:ok, capabilities} = Ecto.Changeset.apply_action(changeset, :insert)

    assert %Capabilities{purge_properties_compression_format: :zlib} = capabilities
  end

  test "capabilities with :purge_properties_compression_format :plaintext" do
    params = %{
      "purge_properties_compression_format" => "plaintext"
    }

    changeset = Capabilities.changeset(%Capabilities{}, params)

    assert %Ecto.Changeset{valid?: true} = changeset

    {:ok, capabilities} = Ecto.Changeset.apply_action(changeset, :insert)

    assert %Capabilities{purge_properties_compression_format: :plaintext} = capabilities
  end

  test "capabilities with invalid :purge_properties_compression_format fails" do
    params = %{
      purge_properties_compression_format: :invalid
    }

    changeset = Capabilities.changeset(%Capabilities{}, params)

    assert %Ecto.Changeset{valid?: false} = changeset
  end
end
