#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.PopulateDBTest do
  use ExUnit.Case
  alias Astarte.Import.PopulateDB

  @realm "test"

  @xml """
  <?xml version="1.0" encoding="UTF-8"?>
  <astarte>
    <devices>
      <device device_id="yKA3CMd07kWaDyj6aMP4Dg">
        <interfaces>
          <interface name="org.astarteplatform.Values" major_version="0" minor_version="1">
            <values path="/realValue">
              <value timestamp="2019-05-31T09:12:42.789379Z">0.1</value>
              <value timestamp="2019-05-31T09:13:29.144111Z">0.2</value>
              <value timestamp="2019-05-31T09:13:52.040373Z">0.3</value>
            </values>
          </interface>
        </interfaces>
      </device>
    </devices>
  </astarte>
  """

  test "Test import into Cassandra database" do
    PopulateDB.populate(@realm, @xml)
  end
end
