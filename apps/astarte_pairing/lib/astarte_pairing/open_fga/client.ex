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

defmodule Astarte.Pairing.OpenFGA.Client do
  @moduledoc """
  HTTP client for the OpenFGA authorization server, wired to the
  `openfga_url` configured in `Astarte.Pairing.Config`.
  """

  use Astarte.Config.HTTPClient, config: Astarte.Pairing.Config, service: :openfga

  # Ignore the dialyzer warning for the macro-injected stream_next/1 function
  @dialyzer {:nowarn_function, stream_next: 1}
end
