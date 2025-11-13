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

defmodule Astarte.Cases.AMQP do
  use ExUnit.CaseTemplate
  require Logger

  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.AMQPTestEventsConsumer

  setup %{realm_name: realm} do
    test_id = System.unique_integer()
    amqp_consumer = start_link_supervised!({AMQPTestHelper, [test_id: test_id]})

    events_consumer =
      start_link_supervised!(
        {AMQPTestEventsConsumer,
         [
           realm: realm,
           consumer: amqp_consumer,
           test_id: test_id
         ]}
      )

    %{test_id: test_id, amqp_consumer: amqp_consumer, events_consumer: events_consumer}
  end
end
