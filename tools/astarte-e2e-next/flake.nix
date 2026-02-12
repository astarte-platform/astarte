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

{
  description = "End to end test and synthetic monitoring for Astarte";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    crane.url = "github:ipetkov/crane";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      perSystem =
        {
          pkgs,
          system,
          self',
          ...
        }:
        let
          toolchain = inputs.rust-overlay.packages.${system}.rust-nightly.override {
            extensions = [
              "rust-src"
              "rust-analyzer"
            ];
          };
          craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;
        in
        {
          packages.default = craneLib.buildPackage {
            src = pkgs.lib.cleanSourceWith {
              src = craneLib.path ./.;
              filter = path: type: craneLib.filterCargoSources path type;
            };
            nativeBuildInputs = [ pkgs.sqlite ];
            strictDeps = true;
          };

          devShells.default = craneLib.devShell {
            inputsFrom = [ self'.packages.default ];
            packages = [ pkgs.cargo-nextest ];
            RUST_SRC_PATH = "${toolchain}";
          };

          devShells.setup = craneLib.devShell { };

          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
