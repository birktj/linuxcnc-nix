{ lib, writeText, fetchurl, tcl, tk, tcllib, zlib, libjpeg, libpng, libtiff }:
tcl.mkTclDerivation rec {
  pname = "tkimg";
  version = "1.4.16";

  src = fetchurl {
    url = "https://downloads.sourceforge.net/tkimg/Img-1.4.16-Source.tar.gz";
    sha256 = "d99af4835fe3e20960817c7a1b5235dcfaa97c642593cce50bdb64c5827cd321";
  };

  # Some platforms encounter runtime errors if compiled with the libs bundled in the source tree
  # system_libs.patch is a combined set of patches taken from debian allowing compiling with system libs
  # but hardcodes /usr/include/, this hacky fix sets nix store paths inside the patch
  # patches = with builtins; [ (writeText "fixed_patch" (replaceStrings
  #   ["/usr/include/zlib.h" "/usr/include/png.h"
  #    "/usr/include/jpeglib.h" "/usr/include/jerror.h"]
  #   ["${zlib.dev}/include/zlib.h" "${libpng.dev}/include/png.h"
  #    "${libjpeg.dev}/include/jpeglib.h" "${libjpeg.dev}/include/jerror.h"]
  #   (readFile ./system_libs.patch))) ];

  meta = {
    homepage = "https://sourceforge.net/projects/tkimg/";
    description = "This package enhances Tk, adding support for many other Image formats: BMP, XBM, XPM, GIF (with transparency, but without LZW), PNG, JPEG, TIFF and postscript.";
    license = lib.licenses.tcltk;
    platforms = lib.platforms.unix;
  };

  buildInputs  = [ tcl tk.dev tk tcllib zlib.dev zlib libjpeg.dev libjpeg libpng.dev libpng libtiff.dev libtiff];

  configureFlags  = [
    "--with-tcl=${tcl}/lib"
    "--with-tk=${tk}/lib"
    "--with-tkinclude=${tk.dev}/include"
  ];
}
