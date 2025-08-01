{ fetchFromGitHub, python3 }:
python3.pkgs.buildPythonPackage {
  pname = "yapps";
  version = "2.2.0";
  pyproject = true;
  build-system = [ python3.pkgs.setuptools ];
  src = fetchFromGitHub {
    owner = "smurfix";
    repo = "yapps";
    rev = "67541062093846bb53f011da0f4d489d63375d2d";
    sha256 = "XDUWuiw6AiUWWHqwSmuU6TfDbK/WRZfBfYgOryBClgI=";
    fetchSubmodules = true;
  };
}
