#!/bin/bash

./bin/astarte_housekeeping_api eval Elixir.Astarte.Housekeeping.API.ReleaseTasks.init_database || exit 1

./bin/astarte_housekeeping_api eval Elixir.Astarte.Housekeeping.API.ReleaseTasks.migrate || exit 1

exec ./bin/astarte_housekeeping_api $@
