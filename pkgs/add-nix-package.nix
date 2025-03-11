{ python3Packages}:

python3Packages.buildPythonApplication {
  pname = "add-nix-package";
  version = "2025-2-3";
  format = "other";

  dontUnpack = true;

  installPhase = ''
    cp ${./add-nix-package} $out/bin/add-nix-package
  '';

  propagatedBuildInputs = [
    textual
  ];

  meta = {
    description = "OCF NixOS script for adding packages to a home manager file";
  };
}