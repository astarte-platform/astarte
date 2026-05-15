#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.Core.Triggers.DataTrigger do
  @moduledoc """
  Defines the struct and types for Astarte data triggers.
  """

  use TypedStruct
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget

  @type amqp_trigger_target :: AMQPTriggerTarget.t()
  @type known_value :: term() | nil
  @type interface_id :: :any_interface | :binary
  @type path_match_tokens :: :any_endpoint | String.t()
  @type value_match_operator ::
          :ANY
          | :EQUAL_TO
          | :NOT_EQUAL_TO
          | :GREATER_THAN
          | :GREATER_OR_EQUAL_TO
          | :LESS_THAN
          | :LESS_OR_EQUAL_TO
          | :CONTAINS
          | :NOT_CONTAINS

  typedstruct do
    field :interface_id, interface_id()
    field :path_match_tokens, path_match_tokens()
    field :value_match_operator, value_match_operator()
    field :known_value, known_value()
    field :trigger_targets, [amqp_trigger_target()], enforce: true
  end

  def are_congruent?(trigger_a, trigger_b) do
    trigger_a.interface_id == trigger_b.interface_id and
      trigger_a.path_match_tokens == trigger_b.path_match_tokens and
      trigger_a.value_match_operator == trigger_b.value_match_operator and
      trigger_a.known_value == trigger_b.known_value
  end
end
