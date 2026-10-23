{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.printhost;

  pythonEnv = config.ocf.python.package.withPackages (
    ps: with ps; [
      ocflib
      pycups
      pymysql
      requests
    ]
  );

  ocfEnforcer = pkgs.stdenv.mkDerivation rec {
    pname = "ocf-enforcer";
    version = "1.0.0";
    src = ./enforcer;

    nativeBuildInputs = [ pkgs.makeWrapper ];
    buildInputs = [ pythonEnv ];

    dontBuild = true;

    postPatch = ''
      substituteInPlace utils.py \
        --replace-fail "@mysqlPasswordFile@" "${cfg.mysqlPasswordFile}" \
        --replace-fail "@wayoutPasswordFile@" "${cfg.wayoutPasswordFile}"
    '';

    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/lib/${pname}

      cp * $out/lib/${pname}/

      makeWrapper ${lib.getExe pythonEnv} $out/bin/${pname} \
        --add-flags "$out/lib/${pname}/main.py" \
        --prefix PYTHONPATH : "$out/lib/${pname}"
    '';

    meta.mainProcess = "${pname}";
  };
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.ocf-enforcer = {
      description = "OCF Print Enforcer";
      wantedBy = [ "multi-user.target" ];
      wants = [ "cups.service" ];
      after = [ "cups.service" ];
      serviceConfig = {
        ExecStart = "${lib.getExe ocfEnforcer}";
        Restart = "on-failure";
        RestartSec = "5s";
	User = "root"; # TODO have a custom user with perms
        #User = "cups"; # user is created in services.printing at services/printing/cupsd.nix
      };
    };
  };
}
