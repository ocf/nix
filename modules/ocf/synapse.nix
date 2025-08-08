{ pkgs, lib, config, ... }:

let 
  cfg = config.ocf.synapse;
in
{
  options.ocf.synapse = {
    enable = lib.mkEnableOption "Enable Synapse";
    
    postgresPackage = lib.mkOption {
      type = lib.types.str;
      description = "PostgreSQL package version, incremented only after manual upgrade.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      description = "Synapse base URL.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      description = "Synapse server name.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.synapse-postgres-passwd.rekeyFile = ../../secrets/master-keyed/synapse-postgres-passwd.age;

    services.postgresql = {
      enable = true;
      package = cfg.postgresPackage;
      ensureDatabases = [ "synapse" ];
      ensureUsers = [
        {
          name = "synapse";
          ensureDBOwnership = true;
        }
      ];
      services.postgresql.initialScript = pkgs.writeText "init-sql-script" ''
        alter user synapse with password '$(cat "${config.age.synapse-postgres-passwd.path}")';
      '';
    };

    services.matrix-synapse = {
      enable = true;
      settings.server_name = cfg.serverName;
      settings.public_baseurl = cfg.baseUrl;
    };
  };
}
