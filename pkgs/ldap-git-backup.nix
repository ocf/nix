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

  # Replace $repo->command('add', @filelist) with $repo->command('add', '-A')
  # to avoid E2BIG (errno 7) when the LDAP database has thousands of entries.
  # git add -A also handles deletions, so the explicit rm command is redundant.
  postPatch = ''
    sed -i \
      -e "s/\\\$repo->command('add', @filelist) if @filelist;/\\\$repo->command('add', '-A');/" \
      -e "/\\\$repo->command('rm', (keys %files_before)) if %files_before;/d" \
      ldap-git-backup
  '';

  postInstall = ''
    patchShebangs $out/sbin/ldap-git-backup
    wrapProgram $out/sbin/ldap-git-backup \
      --prefix PATH : ${git}/bin \
      --prefix PERL5LIB : ${perlPackages.Git}/${perl.libPrefix} \
      --prefix PERL5LIB : ${perlPackages.Error}/${perl.libPrefix}
  '';
}
