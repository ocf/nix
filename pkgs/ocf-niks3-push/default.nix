# FIXME: there has to be a better way of doing this,
#        maybe look into using cellar with oidc when
#        they add it someday (https://github.com/blitz/celler)
{
  python3Packages,
  niks3,
  makeWrapper,
}:

python3Packages.buildPythonApplication {
  pname = "ocf-niks3-push";
  version = "0.1.0";
  format = "other";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  propagatedBuildInputs = with python3Packages; [
    requests
    requests-kerberos
  ];

  installPhase = ''
    install -Dm755 ocf-niks3-push.py $out/bin/niks3-push
    wrapProgram $out/bin/niks3-push \
      --prefix PATH : ${niks3}/bin
  '';
}
