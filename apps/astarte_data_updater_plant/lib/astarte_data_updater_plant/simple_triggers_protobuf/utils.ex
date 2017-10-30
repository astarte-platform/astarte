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

defmodule Astarte.DataUpdaterPlant.SimpleTriggersProtobuf.Utils do
  alias Astarte.DataUpdaterPlant.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.DataUpdaterPlant.SimpleTriggersProtobuf.SimpleTriggerContainer

  def deserialize_trigger_target(payload) do
    %TriggerTargetContainer{
      version: 1,
      trigger_target: {_target_type, target}
    } = TriggerTargetContainer.decode(payload)

    target
  end

  def deserialize_simple_trigger(payload) do
    %SimpleTriggerContainer{
      version: 1,
      simple_trigger: {simple_trigger_type, simple_trigger}
    } = SimpleTriggerContainer.decode(payload)

    {simple_trigger_type, simple_trigger}
  end

end
