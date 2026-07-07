{
  self,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ocf.releaseMetadata;
  variant_id =
    if config.system.nixos.variant_id != null then config.system.nixos.variant_id else "ocf";
  gitRev =
    if (self ? shortRev) then
      self.shortRev
    else if (self ? dirtyShortRev) then
      self.dirtyShortRev
    else
      "nullrev";
in
{
  options.ocf.releaseMetadata.enable = lib.mkEnableOption "Whether to add OCF release metadata";

  config = lib.mkIf cfg.enable {
    system.configurationRevision = gitRev;

    system.nixos = {
      # we do not include self.lastModifiedDate since:
      # - the bootloader menu already includes "built on"
      # - date can be checked from the revision hash with an extra step
      # - label is much shorter without the date
      label = "${variant_id}.${gitRev}.${config.system.nixos.version}";

      vendorName = "Open Computing Facility";
      vendorId = "ocf";

      extraOSReleaseArgs = {
        VENDOR_URL = "https://www.ocf.berkeley.edu/";
        DOCUMENTATION_URL = "https://bestdocs.ocf.io/user-docs/";
        SUPPORT_URL = "https://bestdocs.ocf.io/user-docs/contact/";
        PRIVACY_POLICY_URL = "https://bestdocs.ocf.io/user-docs/privacy/";
        BUG_REPORT_URL = "https://github.com/ocf/nix/issues";
      };
    };
  };
}
