{
    inputs = {
        nixpkgs.url = "nixpkgs/nixos-25.05";
        nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    };
    outputs = { self, nixpkgs, nixos-hardware }@inputs:
    let
        systems = nixpkgs.lib.platforms.linux;
        lib = nixpkgs.lib;
        packagePaths = lib.mapAttrs (n: v: "${./packages}/${n}") (lib.filterAttrs (n: v: v == "directory" && (builtins.readDir "${./packages}/${n}") ? "default.nix") (builtins.readDir ./packages));
    in rec {
      packages = lib.genAttrs systems (system: lib.mapAttrs (n:  v: lib.callPackageWith ((lib.recursiveUpdate packages.${system} nixpkgs.legacyPackages.${system}) // { inherit inputs; inherit system; }) v {}) packagePaths);
      legacyPackages = packages;
      overlay = final: prev: (lib.mapAttrs (n: v: prev.callPackage v { }) packagePaths);
      nixosModules = { linuxcnc = import ./modules/linuxcnc.nix; };


      nixosConfigurations.rpi-linuxcnc = nixpkgs.lib.nixosSystem {
            modules = [
                "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
                "${nixos-hardware}/raspberry-pi/4/default.nix"
                self.nixosModules.linuxcnc
                ({pkgs, config, ...}: {
                    nixpkgs.overlays = [
                        self.overlay
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

                    boot.initrd.availableKernelModules = [
                    "vc4" "bcm2835_dma" "i2c_bcm2835"
                      ];

                    services.xserver = {
    enable = true;
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
     extraConfig = ''
    Section "OutputClass"
      Identifier "vc4"
      MatchDriver "vc4"
      Driver "modesetting"
      Option "PrimaryGPU" "true"
    EndSection
  '';
  };
services.displayManager = {
defaultSession = "xfce";
	autoLogin.enable = true;
	autoLogin.user = "birk";
}                    ;
                    security.sudo = {
                        enable = true;
                        wheelNeedsPassword = false;
                    };
                    users.mutableUsers = false;

                    users.users.birk = {
                        isNormalUser = true;
                        extraGroups = [ "wheel" "dialout" "kmem" "gpio" "plugdev" ]; # Enable ‘sudo’ for the user.
                        openssh.authorizedKeys.keys = [ 
                            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrvdnfRte2aM39d+GdUVt+KI6HqP8opmmuxYXKdBMzF birk@erebus"
                            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuZp5Quo2ubCkxqX6D1DIqKVf+p98ffcNg6f9M6Nc9X birk@granite"
                        ];
                    };

                    # Realtime kernel
                    boot.kernelPackages = pkgs.linuxPackages-rt_latest;

                    boot.extraModulePackages = [
                        (pkgs.bcm2835-gpiomem.override { linuxPackages = config.boot.kernelPackages; })
                    ];

                    boot.kernelModules = [ "bcm2835-gpiomem" ];

                    # Realtime config:
                    # https://dantalion.nl/2024/09/29/linuxcnc-latency-jitter-kernel-parameter-tuning.html
                    # https://manuel.bernhardt.io/posts/2023-11-16-core-pinning/
                    boot.kernelParams = [
                        # Run kernel on cores 0 and 1
                        "irqaffinity=0,1"
                        "kthread_cpus=0,1"

                        "rcu_nocb_poll"
                        "rcu_nocbs=2,3"
                        "isolcpus=managed_irq,domain,2,3"
                        "nohz=on"
                        "nohz_full=2,3"  
                        
                        "skew_tick=1"
                        "nosmt=force"
                        "nosoftlockup"
                        "nowatchdog"

                        # "cpufreq.off=1"
                        # "cpuidle.off=1"

                        "iomem=relaxed"
                        "strict-devmem=0"

                        "cma=256M"

                        "lapic"
                        "noxsave"
                        "acpi_osi="
                        "idle=poll"
                        "acpi_irq_nobalance"
                        "noirqbalance"
                        "vmalloc=32MB"
                        "clocksource=acpi_pm"

                        "video=DSI-1:720x1280@60"
                    ];
                    boot.kernel.sysctl."kernel.timer_migration" = 0;
                    boot.kernel.sysctl."kernel.sched_rt_runtime_us" = -1;


                    # GPIO
                  users.groups.kmem = {};
                  users.groups.gpio = {};
                  users.groups.plugdev = {};
                  services.udev.extraRules = ''
                    SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP:="gpio", MODE:="0660"
                    SUBSYSTEM=="bcm2835-gpiomem", KERNEL=="gpiomem", GROUP="gpio", MODE="0660"
                    ACTION=="add", KERNEL=="mem", MODE="0660"
                  '';

                    hardware.deviceTree = {
                        enable = true;
                        overlays = [
                            { name = "gpiomem"; dtsFile = ./gpiomem.dts; }
                            { name = "vc4-kms-dsi-ili9881-7inch-overlay"; dtsFile = ./vc4-kms-dsi-ili9881-7inch-overlay.dts; }
                        ];
                    };
                    hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;

                    # hardware.raspberry-pi."4".fkms-3d.enable = true;

                    # Setup openssh
                    services.openssh.enable = true;
                    networking.firewall.allowedTCPPorts = [
                        22  
                    ];

                    environment.systemPackages = with pkgs; [
                        vim
                        helix
                        htop
                        rt-tests
                        dtc
                        libraspberrypi
                    ];

                    # Setup network
                    # networking.wireless = {
                    #     enable = true;
                    #     networks.ArkytaNett.psk = "froskspikerpistolvannkanne";
                    # };
                    # networking.hostName = "flap-display-controller";

                    nixpkgs.hostPlatform.system = "aarch64-linux";
                    # nixpkgs.buildPlatform.system = "x86_64-linux";
                    system.stateVersion = "23.11";

                    sdImage.compressImage = false;
                })
            ];
       };

        images.rpi-linuxcnc = self.nixosConfigurations.rpi-linuxcnc.config.system.build.sdImage;
    };
}
