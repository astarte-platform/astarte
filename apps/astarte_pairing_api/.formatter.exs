# SPDX-FileCopyrightText: 2018-2020 SECO Mind Srl
#
# SPDX-License-Identifier: CC0-1.0

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [
    :ecto,
    :phoenix,
    :skogsra
  ]
]
