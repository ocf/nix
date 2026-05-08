{
  stdenv,
  fetchFromGitHub,
  perl,
  perlPackages,
  git,
  makeWrapper,
  autoreconfHook,
}:

stdenv.mkDerivation {
  pname = "ldap-git-backup";
  version = "unstable-2023-01-27";

  src = fetchFromGitHub {
    owner = "elmar";
    repo = "ldap-git-backup";
    rev = "6e0ea0e9bd2b8a52965b06e63c30100508a29428";
    hash = "sha256-En8MBrSRj2zAs+/3XMRhT96UplkpawdBy3OCLYCWn0s=";
  };

  nativeBuildInputs = [
    autoreconfHook
    makeWrapper
    perl
  ];

  postInstall = ''
    wrapProgram $out/sbin/ldap-git-backup \
      --prefix PATH : ${git}/bin \
      --prefix PERL5LIB : ${perlPackages.Git}/${perl.libPrefix} \
      --prefix PERL5LIB : ${perlPackages.Error}/${perl.libPrefix}
  '';
}
