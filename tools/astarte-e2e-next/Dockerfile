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
# SPDX-License-Identifier: Apache-2.0
#

FROM lukemathwalker/cargo-chef:0.1.73-rust-1.91.1-trixie AS chef
WORKDIR /app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json
COPY . .
RUN cargo build --release --bin astarte-e2e-cli

FROM chef AS tester
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --tests --recipe-path recipe.json
COPY . .
RUN cargo test --bin astarte-e2e-cli --no-run
CMD ["cargo", "test", "--bin", "astarte-e2e-cli"]

FROM debian:trixie-20260112-slim AS runtime
WORKDIR /app
COPY --from=builder /app/target/release/astarte-e2e-cli /usr/local/bin/astarte-e2e
ENTRYPOINT ["/usr/local/bin/astarte-e2e"]
