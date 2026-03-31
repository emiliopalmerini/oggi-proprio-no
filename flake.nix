{
  description = "Oggi Proprio No - appointment scheduler";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            elixir
            erlang
            sqlite
            inotify-tools # for Phoenix live reload on Linux
          ];

          shellHook = ''
            export MIX_HOME="$PWD/.mix"
            export HEX_HOME="$PWD/.hex"
            export PATH="$MIX_HOME/bin:$MIX_HOME/escripts:$PATH"
          '';
        };
      });
}
