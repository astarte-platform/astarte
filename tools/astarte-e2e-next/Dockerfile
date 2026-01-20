FROM lukemathwalker/cargo-chef:0.1.78-rust-1.98.0-trixie AS chef
WORKDIR /app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json
COPY . .
RUN cargo build --release --bin astarte-synthetic-monitoring

FROM chef AS end-to-end
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --tests --recipe-path recipe.json
COPY . .
RUN cargo e2e --no-run
CMD ["cargo", "e2e"]

FROM debian:trixie-20260112-slim AS runtime
WORKDIR /app
COPY --from=builder /app/target/release/astarte-synthetic-monitoring /usr/local/bin/astarte-synthetic-monitoring
ENTRYPOINT ["/usr/local/bin/astarte-synthetic-monitoring"]
