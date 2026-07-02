{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.ocf.python.package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.python314;
  };
}
