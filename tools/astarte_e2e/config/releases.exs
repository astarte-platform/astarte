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

mailgun_api_key =
  System.get_env("MAILGUN_API_KEY") ||
    raise """
    environment variable MAILGUN_API_KEY is missing.
    """

mailgun_domain =
  System.get_env("MAILGUN_DOMAIN") ||
    raise """
    environment variable MAILGUN_DOMAIN is missing.
    """

mailgun_base_uri = System.get_env("MAILGUN_BASE_URI") || "https://api.mailgun.net/v3"

config :astarte_e2e, AstarteE2EWeb.Mailer,
  adapter: Bamboo.MailgunAdapter,
  api_key: mailgun_api_key,
  domain: mailgun_domain,
  base_uri: mailgun_base_uri,
  hackney_opts: [
    recv_timeout: :timer.minutes(1)
  ]
