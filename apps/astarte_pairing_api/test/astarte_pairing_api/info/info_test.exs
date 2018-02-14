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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.Pairing.API.InfoTest do
  use Astarte.Pairing.API.DataCase

  alias Astarte.Pairing.API.Info.BrokerInfo
  alias Astarte.Pairing.API.Info
  alias Astarte.Pairing.Mock

  describe "broker_info" do
    test "get_broker_info! returns valid broker_info with given id" do
      assert %BrokerInfo{url: url, version: version} = Info.get_broker_info!()
      assert url == Mock.broker_url()
      assert version == Mock.version()
    end
  end
end
