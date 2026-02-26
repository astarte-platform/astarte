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

defmodule Astarte.Fixtures.Policy do
  @moduledoc """
  Fixtures for policy test data.
  """

  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Astarte.Core.Triggers.Policy.Handler

  def retry_all_handlers do
    handlers_1 = [
      %Handler{on: %ErrorKeyword{keyword: "any_error"}, strategy: "retry"}
    ]

    handlers_2 = [
      %Handler{on: %ErrorKeyword{keyword: "server_error"}, strategy: "retry"},
      %Handler{on: %ErrorKeyword{keyword: "client_error"}, strategy: "retry"}
    ]

    handlers_3 = [
      %Handler{on: %ErrorKeyword{keyword: "server_error"}, strategy: "retry"},
      %Handler{on: %ErrorRange{error_codes: 400..499}, strategy: "retry"}
    ]

    handlers_4 = [
      %Handler{on: %ErrorRange{error_codes: 500..599}, strategy: "retry"},
      %Handler{on: %ErrorRange{error_codes: 400..499}, strategy: "retry"}
    ]

    [handlers_1, handlers_2, handlers_3, handlers_4]
  end

  def discard_all_handlers do
    handlers_1 = [
      %Handler{on: %ErrorKeyword{keyword: "any_error"}, strategy: "discard"}
    ]

    handlers_2 = [
      %Handler{on: %ErrorKeyword{keyword: "server_error"}, strategy: "discard"},
      %Handler{on: %ErrorKeyword{keyword: "client_error"}, strategy: "discard"}
    ]

    handlers_3 = [
      %Handler{on: %ErrorKeyword{keyword: "server_error"}, strategy: "discard"},
      %Handler{on: %ErrorRange{error_codes: 400..499}, strategy: "discard"}
    ]

    handlers_4 = [
      %Handler{on: %ErrorRange{error_codes: 500..599}, strategy: "discard"},
      %Handler{on: %ErrorRange{error_codes: 400..499}, strategy: "discard"}
    ]

    [handlers_1, handlers_2, handlers_3, handlers_4]
  end
end
