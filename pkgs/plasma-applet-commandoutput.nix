{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "plasma-applet-commandoutput";
  version = "13";

  src = fetchFromGitHub {
    owner = "Zren";
    repo = "plasma-applet-commandoutput";
    rev = "7e90654db81ad1088f811d9ad60b355aae956b0c";
    hash = "sha256-26GjKImqwN9JmSOc2hadFxKHYeV24GOa20bU+jox+cM=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/plasma/plasmoids
    cp -r package/ $out/share/plasma/plasmoids/com.github.zren.commandoutput

    runHook postInstall
  '';

  meta = {
    description = "Run command every second and displays the output.";
    homepage = "https://github.com/Zren/plasma-applet-commandoutput";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
