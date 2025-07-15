{ lib, config, ... }:

let
  cfg = config.ocf.secrets;
in
{
  options.ocf.secrets = {
    enable = lib.mkEnableOption "Enable OCF nix secrets management for this host";
    hostKey = lib.mkOption {
      description = "Host SSH public key you can get this by running `ssh-keyscan -t ed25519 <host>` on supernova";
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    age.rekey = {
      hostPubkey = cfg.pubKey;
      masterIdentities = lib.filesystem.listFilesRecursive ./master-identities;
      storageMode = "local";
      localStorageDir = ./. + "modules/ocf/secrets/rekeyed/${config.networking.hostName}";
    };
  };
}
