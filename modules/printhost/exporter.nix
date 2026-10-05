{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.ocf.printhost.exporter;
  prom = config.ocf.prometheus-export;
in
{
  options.ocf.logged-in-users-exporter.enable = lib.mkEnableOption "printer stats exporter";
  config = lib.mkIf cfg.enable {
    prom.textFileScripts = lib.singleton pkgs.writeShellScriptBin "printer-stats-exporter" ''
      output_file="${prom.textFileDir}/printer_stats.prom"
      > "$output_file"

      # code here

      echo "attri{name=\"$user\", state=\"$locked_status\"} 1" > "$output_file"
    '';
  };
}
