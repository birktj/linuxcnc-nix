{ lib,
  stdenv,
  autoreconfHook,
  wrapGAppsHook,
  qt5,
  makeWrapper,
  fetchFromGitHub,
  libtool,
  pkg-config,
  readline_5,
  ncurses,
  libtirpc,
  systemd,
  libmodbus,
  libusb1,
  glib,
  gtk2,
  gtk3,
  procps,
  kmod,
  sysctl,
  util-linux,
  psmisc,
  intltool,
  tcl,
  tk,
  bwidget,
  tkimg,
  tclx,
  tkblt,
  pango,
  cairo,
  boost,
  espeak,
  gst_all_1,
  python3,
  yapps,
  gobject-introspection,
  libGLU, xorg,
  libepoxy,
  hicolor-icon-theme,
  glxinfo,
  asciidoc,
  groff,
  libgpiod,
  bash
}:
let
  pythonPkg = (python3.withPackages (ps: [
    yapps
    ps.pyopengl
    ps.pygobject3
    ps.pycairo
    ps.boost
    ps.numpy
    ps.pyqtwebengine
    ps.pyqt5
    ps.opencv4
    ps.gst-python
    ps.xlib
    ps.qscintilla
    ps.boost
    ps.tkinter
  ]));
  # boost_python = (boost.override { enablePython = true; python = pythonPkg; });
in
stdenv.mkDerivation rec {
  hardeningDisable = [ "all" ];
  enableParalellBuilding = true;
  pname = "linuxcnc";
  version = "2.9.4";
  name = "${pname}-${version}";

  enableParallelBuilding = true;

  src = fetchFromGitHub {
    owner = "LinuxCNC";
    repo = "linuxcnc";
    rev = "v2.9.4";
    sha256 = "sha256-E74Kh5TqWPAQ22ohgLsYICNqYgOuhAwK2JJ+/1TfgU4=";
  };

  nativeBuildInputs = [
    autoreconfHook
    makeWrapper
    wrapGAppsHook
    qt5.wrapQtAppsHook
    gobject-introspection
    asciidoc
    groff
  ];

  dontWrapGApps = true;
  dontWrapQtApps = true;

  buildInputs = [
    libtool pkg-config libtirpc systemd libmodbus libusb1 glib gtk2 gtk3 procps kmod sysctl util-linux
    psmisc intltool tcl tk bwidget tkimg tclx tkblt pango cairo pythonPkg.pkgs.pygobject3 gobject-introspection
    pythonPkg.pkgs.boost pythonPkg qt5.qtbase espeak gst_all_1.gstreamer
    ncurses readline_5 libGLU xorg.libXmu libepoxy hicolor-icon-theme glxinfo libgpiod
  ];

  preAutoreconf = ''
    # cd into ./src here instead of setting sourceRoot as the build process uses the original sourceRoot
    cd ./src

    # make halcmd search for setuid apps on PATH, to find setuid wrappers
    substituteInPlace hal/utils/halcmd_commands.cc --replace 'EMC2_BIN_DIR "/' '"'
  '';

  patches = [
    ./fix_make.patch          # Some lines don't respect --prefix
    ./pncconf_paths.patch     # Corrects a search path in pncconf
    ./rtapi_app_setuid.patch  # Remove hard coded checks for setuid from rtapi_app
    ./cpuinfo.patch
  ];

  postAutoreconf = ''
    # We need -lncurses for -lreadline, but the configure script discards the env set by NixOS before checking for -lreadline
    substituteInPlace configure --replace '-lreadline' '-lreadline -lncurses'

    substituteInPlace emc/usr_intf/pncconf/private_data.py --replace '/usr/share/themes' '${gtk3}/share/themes'
    substituteInPlace emc/usr_intf/pncconf/private_data.py --replace 'self.FIRMDIR = "/lib/firmware/hm2/"' 'self.FIRMDIR = os.environ.get("HM2_FIRMWARE_DIR", "${placeholder "out"}/firmware/hm2")'

    substituteInPlace hal/drivers/mesa-hostmot2/hm2_eth.c --replace '/sbin/iptables' '/run/current-system/sw/bin/iptables'
    substituteInPlace hal/drivers/mesa-hostmot2/hm2_eth.c --replace '/sbin/sysctl' '${sysctl}/bin/sysctl'
    substituteInPlace hal/drivers/mesa-hostmot2/hm2_rpspi.c --replace '/sbin/modprobe' '${kmod}/bin/modprobe'
    substituteInPlace hal/drivers/mesa-hostmot2/hm2_rpspi.c --replace '/sbin/rmmod' '${kmod}/bin/rmmod'
    substituteInPlace module_helper/module_helper.c --replace '/sbin/insmod' '${kmod}/bin/insmod'
    substituteInPlace module_helper/module_helper.c --replace '/sbin/rmmod' '${kmod}/bin/rmmod'
  '';

  configureFlags = [
    "--with-tclConfig=${tcl}/lib/tclConfig.sh"
    "--with-tkConfig=${tk}/lib/tkConfig.sh"
    "--with-boost-libdir=${pythonPkg.pkgs.boost}/lib"
    "--with-boost-python=boost_python3"
    "--with-locale-dir=$(out)/locale"
    "--exec-prefix=${placeholder "out"}"
    # "--enable-non-distributable=yes"
  ];

  postConfigure = ''
    substituteInPlace Makefile --replace 'gnu++11' 'gnu++14'
  '';

  preInstall = ''
    # Stop the Makefile attempting to set ownship+perms, it fails on NixOS
    sed -i -e 's/chown.*//' -e 's/-o root//g' -e 's/-m [0-9]\+//g' Makefile
    substituteInPlace Makefile --replace '/usr/share/applications' '$(prefix)/share/applications'
  '';

  installFlags = [ "SITEPY=${placeholder "out"}/${pythonPkg.sitePackages}" ]; # "DESTDIR=${placeholder "out"}" "prefix=" "bindir=/bin" "libdir=/lib" ];

  postInstall = ''
    mkdir -p "$out/firmware/hm2"
    ln -s "$out/share/linuxcnc/ncfiles" "$out/share/doc/linuxcnc/examples/nc_files"
    rm -rf "$out/share/doc/linuxcnc/examples/sample-configs/sim/axis/orphans"
  '';

  # Binaries listed here are renamed to ${filename}-nosetuid, to be targetted by setuid wrappers
  setuidApps = [ "rtapi_app" "linuxcnc_module_helper" "pci_write" "pci_read" ];

  preFixup = ''
    for prog in $(find $out/bin -type f ! \( ${lib.concatMapStringsSep " -o " (f: "-name " + f + " ") setuidApps} \)); do
      wrapProgram "$prog" \
        --prefix PATH : ${lib.makeBinPath [tk glxinfo]} \
        --prefix TCLLIBPATH ' ' "$out/lib/tcltk/linuxcnc ${tk}/lib ${tcl}/lib ${tclx}/lib ${tkblt}/lib/tcl8.6/blt2.4 ${tkimg}/lib ${bwidget}/lib/bwidget${bwidget.version}" \
        --prefix PYTHONPATH : "${pythonPkg}/${pythonPkg.sitePackages}:$out/${pythonPkg.sitePackages}" \
        "''${gappsWrapperArgs[@]}" \
        "''${qtWrapperArgs[@]}"
    done
    for prog in $(find $out/bin -type f \( ${lib.concatMapStringsSep " -o " (f: "-name " + f + " ") setuidApps} \)); do
      mv "$prog" "$prog-nosetuid"
    done
  '';
}
