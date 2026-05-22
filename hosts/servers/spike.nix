{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  # allows spike to build for raspberry pi
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  ocf.network = {
    enable = true;
    lastOctet = 24;
  };

  ocf.github-actions = {
    enable = true;
    runners = [
      {
        enable = true;
        repo = "nix";
        workflow = "deploy";
        instances = 1;
      }
      {
        enable = true;
        repo = "nix";
        workflow = "build";
        instances = 4;
      }
      {
        enable = true;
        repo = "mkdocs";
      }
      {
        enable = true;
        repo = "decalweb";
      }
    ];
  };

  ocf.niks3-push = {
    enable = true;
    apiTokenFile = config.age.secrets.niks3-api-token.path;
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

  system.stateVersion = "24.11";
}
