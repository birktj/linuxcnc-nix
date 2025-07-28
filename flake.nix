{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };
  outputs = { self, nixpkgs, flake-compat, nixos-hardware }@inputs:
    let
      systems = nixpkgs.lib.platforms.linux;
      lib = nixpkgs.lib;
      packagePaths = lib.mapAttrs (n: v: "${./packages}/${n}") (lib.filterAttrs (n: v: v == "directory" && (builtins.readDir "${./packages}/${n}") ? "default.nix") (builtins.readDir ./packages));
    in rec {
      packages = lib.genAttrs systems (system: lib.mapAttrs (n:  v: lib.callPackageWith ((lib.recursiveUpdate packages.${system} nixpkgs.legacyPackages.${system}) // { inherit inputs; inherit system; }) v {}) packagePaths);
      legacyPackages = packages;
      overlay = final: prev: (lib.mapAttrs (n: v: prev.callPackage v { }) packagePaths);
      nixosModules = { linuxcnc = import ./modules/linuxcnc.nix; };


      nixosConfigurations.flap-display-controller = nixpkgs.lib.nixosSystem {
            modules = [
                "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
                "${nixos-hardware}/raspberry-pi/4/pkgs-overlays.nix"
                self.nixosModules.linuxcnc
                ({pkgs, ...}: {
                    nixpkgs.overlays = [
                        self.overlay
                        (final: prev: {
                            python312 = prev.python312.override {
                                packageOverrides = pyself: pysuper: {
                                    psutil = pysuper.psutil.overrideAttrs (_: {
                                        # doCheck = false;
                                        # doInstallCheck = false;
                                    });
                                };
                            };
                        })
                    ];

                    # nixpkgs.buildPlatform = "x86_64-linux";

                    local.packages.linuxcnc.enable = true;
                
                    # Setup nix flakes
                    nix.settings.experimental-features = [ "nix-command" "flakes" ];
                    nix.registry = {
                        nixpkgs.to = {
                            type = "path";
                            path = pkgs.path;
                        };
                    };
                    nix.settings.trusted-users = ["@wheel"];
                    
                    security.sudo = {
                        enable = true;
                        wheelNeedsPassword = false;
                    };
                    users.mutableUsers = false;

                    users.users.birk = {
                        isNormalUser = true;
                        extraGroups = [ "wheel" "dialout" ]; # Enable ‘sudo’ for the user.
                        openssh.authorizedKeys.keys = [ 
                            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrvdnfRte2aM39d+GdUVt+KI6HqP8opmmuxYXKdBMzF birk@erebus"
                            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuZp5Quo2ubCkxqX6D1DIqKVf+p98ffcNg6f9M6Nc9X birk@granite"
                        ];
                    };

                    # Setup openssh
                    services.openssh.enable = true;
                    networking.firewall.allowedTCPPorts = [
                        22  
                    ];

                    environment.systemPackages = with pkgs; [
                        vim
                        helix
                        picocom
                        i2c-tools
                        dtc
                        flap-display-controller
                    ];

                    # Setup network
                    networking.wireless = {
                        enable = true;
                        networks.ArkytaNett.psk = "froskspikerpistolvannkanne";
                    };
                    networking.hostName = "flap-display-controller";

                    # Setup RTC
                    hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;
                    hardware.deviceTree = {
                        enable = true;
                        overlays = [
                            { name = "i2c-rtc"; dtsFile = ./nix/rtc/i2c-rtc.dts; }
                        ];
                    };
                    
                    nixpkgs.hostPlatform.system = "aarch64-linux";
                    # nixpkgs.buildPlatform.system = "x86_64-linux";
                    system.stateVersion = "23.11";

                    sdImage.compressImage = false;
                })
            ];
       };

        images.flap-display-controller = self.nixosConfigurations.flap-display-controller.config.system.build.sdImage;
    };
}
