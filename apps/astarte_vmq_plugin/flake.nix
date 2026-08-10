{
  description = "Astarte VerneMQ plugin publishes incoming messages on an AMQP exchange with some additional metadata, so they can be processed by other components.";
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
    };
  };
  outputs = { self, nixpkgs, elixir-utils, flake-utils, ... }:
    {
      overlays.default = elixir-utils.lib.asdfOverlay {
        toolVersions = ./.tool-versions;
        wxSupport = false;
      };
    } //
    flake-utils.lib.eachSystem elixir-utils.lib.defaultSystems (system:
      let pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; };
      in {
        devShells.default = pkgs.elixirDevShell;
        formatter = pkgs.nixpkgs-fmt;
      });
}
