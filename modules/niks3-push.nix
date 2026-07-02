{
  lib,
  config,
  ...
}:

let
  cfg = config.ocf.niks3-push;
in
{
  options.ocf.niks3-push = {
    enable = lib.mkEnableOption "Auto-push built paths to the OCF binary cache";

    cacheDomain = lib.mkOption {
      type = lib.types.str;
      description = "Domain of the niks3 cache server.";
      default = "cache.ocf.berkeley.edu";
    };

    apiTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the niks3 API token.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.niks3-auto-upload = {
      enable = true;
      serverUrl = "https://${cfg.cacheDomain}";
      authTokenFile = cfg.apiTokenFile;
    };
  };
}
