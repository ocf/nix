{
  lib,
  formats,
  stdenvNoCC,
  fetchFromGitHub,
  themeConfig ? null,
}:

let
  config = (formats.ini { }).generate "theme.conf.user" themeConfig;
  writeConfig = lib.optionalString (lib.isAttrs themeConfig) ''
    for dir in $out/share/sddm/themes/catppuccin-*/; do
      ln -sf ${config} $dir/theme.conf.user
    done
  '';
in

stdenvNoCC.mkDerivation {
  pname = "catppuccin-sddm";
  version = "2024-03-13-salkfjaslk";

  src = fetchFromGitHub {
    owner = "oliver-ni";
    repo = "sddm";
    rev = "4cf322189908587723e4f344469e5fec54cb1e0d";
    # sha256 = lib.fakeSha256;
    hash = "sha256-XmfWkvoCuNHv9NaUjuP8bldF1fnwO4HaX70douDxfbQ=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/sddm/themes/
    cp -r src/catppuccin-* $out/share/sddm/themes/
    echo "QtVersion=6" | tee -a $out/share/sddm/themes/catppuccin-*/metadata.desktop
    ${writeConfig}

    runHook postInstall
  '';

  meta = {
    description = "Soothing pastel theme for SDDM";
    homepage = "https://github.com/catppuccin/sddm";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
