{
  fetchFromGitHub,
  perlPackages,
  git,
}:

perlPackages.buildPerlPackage {
  pname = "ldap-git-backup";
  version = "unstable-2023-01-27";

  src = fetchFromGitHub {
    owner = "elmar";
    repo = "ldap-git-backup";
    rev = "6e0ea0e9bd2b8a52965b06e63c30100508a29428";
    hash = "sha256-En8MBrSRj2zAs+/3XMRhT96UplkpawdBy3OCLYCWn0s=";
  };

  propagatedBuildInputs = [ perlPackages.Git ];

  postInstall = ''
    wrapProgram $out/sbin/ldap-git-backup \
      --prefix PATH : ${git}/bin
  '';
}
