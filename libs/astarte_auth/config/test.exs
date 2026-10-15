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

import Config

config :astarte_auth, :openfga_url, "http://localhost:8081"
config :astarte_auth, :openfga_store_id, "test_store_id"

config :astarte_auth, Astarte.Auth.TestGuardian,
  allowed_algos: ["HS512"],
  issuer: "astarte_auth_test",
  secret_key: "fr2+g4olPhuLNwj9bQzEF06ESUmtGNk+LRu+JTFH2tCZMGL8+0tFuVLhhLGPAd0Q"
