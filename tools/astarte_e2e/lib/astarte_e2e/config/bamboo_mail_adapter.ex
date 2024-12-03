# Copyright 2017-2020 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E.Config.BambooMailAdapter do
  use Skogsra.Type

  def cast(value) when is_binary(value) do
    case value do
      "mailgun" ->
        {:ok, Bamboo.MailgunAdapter}

      "sendgrid" ->
        {:ok, Bamboo.SendGridAdapter}

      _ ->
        :error
    end
  end

  def cast(_) do
    :error
  end
end
