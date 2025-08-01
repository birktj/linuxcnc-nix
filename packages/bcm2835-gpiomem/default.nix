# Derivation for the out-of-tree build of the Linux driver.
{ lib
, stdenv
, linuxPackages
, kernel ? linuxPackages.kernel  # The Linux kernel Nix package for which this module will be compiled.
}:
stdenv.mkDerivation {
  pname = "bcm2835-gpiomem";
  version = "0.0.0-dev";
  src = ./.;
  nativeBuildInputs = kernel.moduleBuildDependencies;
  makeFlags = kernel.makeFlags ++ [
    # Variable refers to the local Makefile.
    "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    # Variable of the Linux src tree's main Makefile.
    "INSTALL_MOD_PATH=$(out)"
  ];
  buildFlags = [ "modules" ];
  installTargets = [ "modules_install" ];
}
