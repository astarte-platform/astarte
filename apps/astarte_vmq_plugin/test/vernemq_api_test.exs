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

defmodule Astarte.VMQ.Plugin.VerneMQ.APITest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.VMQ.Plugin.VerneMQ.API

  @subscriber_id "realm/device_id"

  describe "disconnect_by_subscriber_id/2" do
    test "returns :ok when the underlying API returns :ok" do
      stub(:vernemq_dev_api, :disconnect_by_subscriber_id, fn _sid, _opts -> :ok end)
      assert :ok = API.disconnect_by_subscriber_id(@subscriber_id, [])
    end

    test "returns :not_found when the underlying API returns :not_found" do
      stub(:vernemq_dev_api, :disconnect_by_subscriber_id, fn _sid, _opts -> :not_found end)
      assert :not_found = API.disconnect_by_subscriber_id(@subscriber_id, [])
    end

    test "passes subscriber_id and opts to the underlying API" do
      opts = [:do_cleanup]

      expect(:vernemq_dev_api, :disconnect_by_subscriber_id, fn sid, o ->
        assert sid == @subscriber_id
        assert o == opts
        :ok
      end)

      assert :ok = API.disconnect_by_subscriber_id(@subscriber_id, opts)
    end

    test "returns :ok when the process exits with :normal" do
      stub(:vernemq_dev_api, :disconnect_by_subscriber_id, fn _sid, _opts ->
        exit(:normal)
      end)

      assert :ok = API.disconnect_by_subscriber_id(@subscriber_id, [])
    end

    test "returns :ok when the process exits with {:normal, reason}" do
      stub(:vernemq_dev_api, :disconnect_by_subscriber_id, fn _sid, _opts ->
        exit({:normal, :some_reason})
      end)

      assert :ok = API.disconnect_by_subscriber_id(@subscriber_id, [])
    end

    test "returns :ok when the process exits with :shutdown" do
      stub(:vernemq_dev_api, :disconnect_by_subscriber_id, fn _sid, _opts ->
        exit(:shutdown)
      end)

      assert :ok = API.disconnect_by_subscriber_id(@subscriber_id, [])
    end

    test "returns :ok when the process exits with {:shutdown, reason}" do
      stub(:vernemq_dev_api, :disconnect_by_subscriber_id, fn _sid, _opts ->
        exit({:shutdown, :some_reason})
      end)

      assert :ok = API.disconnect_by_subscriber_id(@subscriber_id, [])
    end

    test "returns :ok when the process exits with :noproc" do
      stub(:vernemq_dev_api, :disconnect_by_subscriber_id, fn _sid, _opts ->
        exit(:noproc)
      end)

      assert :ok = API.disconnect_by_subscriber_id(@subscriber_id, [])
    end

    test "returns :ok when the process exits with {:noproc, reason}" do
      stub(:vernemq_dev_api, :disconnect_by_subscriber_id, fn _sid, _opts ->
        exit({:noproc, :some_reason})
      end)

      assert :ok = API.disconnect_by_subscriber_id(@subscriber_id, [])
    end
  end
end
