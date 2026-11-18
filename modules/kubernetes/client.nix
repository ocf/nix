{
  config,
  pkgs,
  lib,
  ...
}:
let
  # surely there's a better way
  curlSpnego = pkgs.writeShellScript "curl-spnego" "${lib.getExe pkgs.curl} --negotiate -u : --location-trusted -o /dev/null -sS $@";

  kubeconfig = pkgs.writeText "kubeconfig" (
    lib.replaceString "curl-spnego" "${curlSpnego}" (builtins.readFile ./kubeconfig)
  );

  cfg = config.ocf.kubernetes.client;
in
{
  options.ocf.kubernetes.client = {
    enable = lib.mkEnableOption "enable client tools for managing the ocf kubernetes cluster";
    oidcLogin.enable = lib.mkEnableOption "enable configuration for kubelogin-oidc";
  };

  config = lib.mkIf cfg.enable {
    environment = lib.mkMerge [
      {
        systemPackages =
          with pkgs;
          [
            kubectl
            kubectl-rook-ceph
            fluxcd
            argocd
          ]
          ++ lib.optionals cfg.oidcLogin.enable (with pkgs; [ kubelogin-oidc ]);
      }
      (lib.mkIf cfg.oidcLogin.enable {
        # link in a well known location in case people need to point to it in scripts
        etc."ocf-kubernetes/kubeconfig".source = kubeconfig;
        variables.KUBECONFIG = "${kubeconfig}";
      })
    ];
  };
}
