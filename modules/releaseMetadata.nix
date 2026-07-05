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

    # we do not include self.lastModifiedDate since:
    # - the bootloader menu already includes "built on"
    # - date can be checked from the revision hash with an extra step
    # - label is much shorter without the date
    system.nixos.label = "${variant_id}.${gitRev}.${config.system.nixos.version}";
  };
}
