# Copyright 2023-2024 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

{
  description = "Open Source IoT platform focused on Data management and processing";
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    elixir-utils = {
      url = "github:noaccOS/elixir-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };
  outputs = { self, nixpkgs, elixir-utils, flake-utils, ... }:
    {
      overlays.default = elixir-utils.lib.asdfOverlay { toolVersions = ./.tool-versions; };
    } //
    flake-utils.lib.eachSystem elixir-utils.lib.defaultSystems (system:
      let pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; };
      in {
        devShells.default = pkgs.elixirDevShell;
        formatter = pkgs.nixpkgs-fmt;
      });
}
