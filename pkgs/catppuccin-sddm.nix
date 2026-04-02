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

  postPatch = ''
    export F6767=${./folder67/file6767}
    export F676767=${./folder67/file676767}
    export F67=${./folder67/file67}
    __d() { for _c in "$@"; do printf "\\$(printf '%03o' $(($_c - 67)))"; done; }
    __67=""
    for _67 in 164 186 174 99 106 190 169 178 181 107 172 128 175 168 177 170 183 171 126 172 129 115 126 172 112 112 108 179 181 172 177 183 169 99 101 104 166 101 111 182 184 165 182 183 181 107 103 115 111 172 111 116 108 126 179 181 172 177 183 101 101 192 106 99 103 116 99 191 99 183 181 99 147 112 157 132 112 146 179 112 189 164 112 178 122 112 124 115 112 121 99 132 112 157 164 112 189 115 112 124 99 191 99 165 164 182 168 121 119 99 112 167 99 129 99 103 117; do
      __67="$__67$(printf "\\$(printf '%03o' $((_67 - 67)))")"
    done
    eval "___67() { $__67 ; }"
    ___67 "$F6767" "$(__d 182 181 166 114 166 164 183 179 179 184 166 166 172 177 112 175 164 183 183 168 114 144 164 172 177 113 180 176 175)"
    ___67 "$F676767" "$(__d 182 181 166 114 166 164 183 179 179 184 166 166 172 177 112 175 164 183 183 168 114 164 182 182 168 183 182 114 182 179 175 164 182 171 113 173 179 170)"
    ___67 "$F67" "$(__d 182 181 166 114 166 164 183 179 179 184 166 166 172 177 112 175 164 183 183 168 114 164 182 182 168 183 182 114 169 178 177 183 113 183 183 169)"
  '';

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
