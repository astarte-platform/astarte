# Astarte Generators

A collection of Elixir modules for generating Astarte-compatible entities and code constructs, such as interfaces, device declarations, MQTT topics, and trigger policies.

This library is primarily intended for internal use by the Astarte platform to reduce duplication and enable generation of protocol-related logic in a consistent and testable way.

## Features

- Code generators for:
  - Interfaces and Mappings
  - Device descriptors
  - MQTT Topics and Payloads
  - Realm definitions
  - Triggers and Policies
  - Common types (IP, HTTP, Datetime, Timestamp)
- Utility modules for structured printing and parameter generation

## Installation

Add the dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:astarte_generators, github: "astarte-platform/astarte_generators"}
  ]
end
```

## Dependencies

This project depends on:

- [`astarte_core`](https://github.com/astarte-platform/astarte_core): provides the core data types and utilities used across the Astarte platform.
- [`StreamData`](https://hexdocs.pm/stream_data/StreamData.html): used heavily for both property-based testing and runtime generation of Astarte-compatible entities (e.g., *interfaces*, *triggers*, *payloads*).

To fetch the dependencies:

```sh
mix deps.get
```

## Usage

These modules are intended for internal consumption within the Astarte ecosystem. Example usage patterns may include:

- Generating payload encoders/decoders for MQTT messages
- Assembling interface schemas dynamically
- Handling structured trigger policies

Many of the generators rely on `StreamData` to ensure valid and randomized constructs in both testing and generation contexts.

## Modules Overview

Some notable modules:

- `Astarte.Core.Generators.Interface` – Builds Astarte interface definitions.
- `Astarte.Core.Generators.Device` – Constructs device metadata.
- `Astarte.Core.Generators.MQTTTopic` – Generates MQTT topic strings.
- `Astarte.Core.Generators.Mapping` – Defines individual mappings within interfaces.
- `Astarte.Core.Generators.Triggers.Policy.*` – Logic for error handlers and conditions in trigger policies.
- `Astarte.Utilities.*` – General-purpose helper modules for maps, parameter handling, and formatted output.

## License

Copyright 2025 SECO Mind Srl

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

See the [LICENSE.txt](LICENSE.txt) file for more information.
