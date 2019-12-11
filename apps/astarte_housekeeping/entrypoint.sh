#!/bin/bash

./bin/astarte_housekeeping command Elixir.Astarte.Housekeeping.ReleaseTasks init_database || exit 1

exec ./bin/astarte_housekeeping $@
