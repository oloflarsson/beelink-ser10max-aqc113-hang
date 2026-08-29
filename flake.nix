{
  description = "Beelink SER10 MAX AQC113 hang: reproducer, monitor, workaround";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      wrap = name: path: deps: pkgs.writeShellApplication {
        inherit name; runtimeInputs = deps; text = ''exec ${path} "$@"'';
      };
    in {
      packages.${system} = {
        avxburn = pkgs.runCommandCC "avxburn" { } ''
          mkdir -p $out/bin
          cc -O2 -pthread -mavx512f -mavx2 -mfma -o $out/bin/avxburn ${./not-reproducing/avxburn.c}
        '';
        monitor = wrap "aqc113-monitor" ./reproduce/box/monitor.sh
          (with pkgs; [ coreutils gawk iputils pciutils gnugrep ]);
        recover = wrap "aqc113-recover" ./reproduce/box/recover.sh
          (with pkgs; [ coreutils iproute2 ethtool ]);
        bursts = wrap "aqc113-bursts" ./reproduce/client/bursts.sh
          (with pkgs; [ coreutils curl openssh ]);
        cap = wrap "aqc113-cap-boost" ./workaround/cap-boost.sh [ pkgs.coreutils ];
      };

      apps.${system} = builtins.mapAttrs
        (name: pkg: { type = "app"; program = "${pkg}/bin/${pkg.meta.mainProgram or (builtins.head (builtins.attrNames (builtins.readDir "${pkg}/bin")))}"; })
        self.packages.${system};

      # Persistent workaround for a NixOS host: imports = [ inputs.aqc113.nixosModules.workaround ];
      nixosModules.workaround = import ./workaround/nixos.nix;
    };
}
