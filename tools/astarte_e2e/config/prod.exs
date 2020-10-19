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

use Mix.Config

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [:module, :function, :tag]

sendgrid_api_key =
  System.get_env("SENDGRID_API_KEY") ||
    raise """
    environment variable SENDGRID_API_KEY is missing.
    """

config :astarte_e2e, AstarteE2EWeb.Mailer,
  adapter: Bamboo.SendGridAdapter,
  api_key: sendgrid_api_key,
  hackney_opts: [
    recv_timeout: :timer.minutes(1)
  ]
