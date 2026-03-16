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

defmodule Astarte.FDO.OwnerOnboarding.DeviceAttestationTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.OwnerOnboarding.DeviceAttestation
  alias COSE.Keys.ECC, as: Keys

  describe "eb_sig_info/1" do
    test "returns :es256 sig info for an es256 device signature" do
      key = Keys.generate(:es256)
      device_signature = {:es256, key}

      assert :es256 = DeviceAttestation.eb_sig_info(device_signature)
    end

    test "returns :es384 sig info for an es384 device signature" do
      key = Keys.generate(:es384)
      device_signature = {:es384, key}

      assert :es384 = DeviceAttestation.eb_sig_info(device_signature)
    end
  end
end
