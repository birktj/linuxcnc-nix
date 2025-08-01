{ lib, fetchurl, tcl, tk, xorg }:
tcl.mkTclDerivation rec {
  pname = "tkblt";
  version = "2.5.3";

  src = fetchurl {
    url = "http://downloads.sourceforge.net/blt/BLT2.4z.tar.gz";
    sha256 = "sha256-becF7M8uxna0Bxt07J4hHFkEd/rfbwVWbP2O1qA8YNo=";
  };

  patches = [
    ./blt2.4z-patch-2
    ./blt2.4z-patch-64
    ./blt2.4-tk8.5.patch
    ./blt2.4z-destdir.patch
    ./blt2.4z-norpath.patch
    ./blt2.4z-noexactversion.patch
    ./blt2.4z-zoomstack.patch
    ./blt2.4z-tk8.5.6-patch
    ./blt2.4z-tcl8.6.patch
    ./blt2.4z-tk8.6.patch
    ./blt-configure-c99.patch
    ./solib-deps.patch
  ];

  postPatch = ''
    mv man/graph.mann man/bltgraph.mann
	  mv man/bitmap.mann man/bltbitmap.mann
  '';

  meta = {
    homepage = "https://sourceforge.net/projects/wize/";
    description = "BLT for Tcl/Tk with patches from Debian";
    license = lib.licenses.tcltk;
    platforms = lib.platforms.unix;
  };

  buildInputs  = [ tcl tk.dev tk xorg.libX11 xorg.libXext ];

  configureFlags  = [
    "--with-tcl=${tcl}/lib"
    "--with-tk=${tk}/lib"
    "--with-tkincls=${tk.dev}/include"
    "--with-tclincls=${tcl}/include"
    "--x-includes=${xorg.libXext}/include"
    "--x-libraries=${xorg.libX11}/lib"
  ];

  # preFixup = ''
  #   substituteInPlace $out/lib/blt2.5/pkgIndex.tcl --replace 'package ifneeded BLT $version' 'package ifneeded BLT ${version}'
  # '';

}
