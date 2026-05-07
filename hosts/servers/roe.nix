{ config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "roe";

  ocf.network = {
    enable = true;
    lastOctet = 52;
  };

  ocf.niks3-cache = {
    enable = true;
    apiTokenFile = config.age.secrets.niks3-api-token.path;
    signingKeyFile = config.age.secrets.niks3-signing-key.path;
    s3AccessKeyFile = config.age.secrets.niks3-s3-access-key.path;
    s3SecretKeyFile = config.age.secrets.niks3-s3-secret-key.path;
  };

  age.secrets.niks3-api-token = {
    rekeyFile = ../../secrets/master-keyed/niks3-cache/niks3-api-token.age;
    owner = "niks3";
  };
  age.secrets.niks3-signing-key = {
    rekeyFile = ../../secrets/master-keyed/niks3-cache/niks3-signing-key.age;
    owner = "niks3";
  };
  age.secrets.niks3-s3-access-key = {
    rekeyFile = ../../secrets/master-keyed/niks3-cache/niks3-s3-access-key.age;
    owner = "niks3";
  };
  age.secrets.niks3-s3-secret-key = {
    rekeyFile = ../../secrets/master-keyed/niks3-cache/niks3-s3-secret-key.age;
    owner = "niks3";
  };

  system.stateVersion = "25.05";
}
