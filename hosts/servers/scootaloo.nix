{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "scootaloo";

  ocf.network = {
    enable = true;
    lastOctet = 29;
  };

  ocf.irc = {
    enable = true;
  };

  ocf.matrix = {
    enable = true;
    postgresPackage = pkgs.postgresql_16;

    discord-bridge.enable = true;
    element.enable = true;
    irc-bridge.enable = true;

    initialRooms = [
      "#_discord_735620315111096391_761065162450272286:ocf.io"
      "#_discord_735620315111096391_735624339847643277:ocf.io"
      "#_discord_735620315111096391_736066924592758785:ocf.io"
      "#_discord_735620315111096391_833090052996857876:ocf.io"
      "#_discord_735620315111096391_1012214233322246214:ocf.io"
      "#_discord_735620315111096391_735624292179640331:ocf.io"
      "#_discord_735620315111096391_735624203860181135:ocf.io"
      "#_discord_735620315111096391_881325795044368414:ocf.io"
      "#_discord_735620315111096391_736005105068802109:ocf.io"
    ];

    irc-bridge.initialRooms = {
      "#announcements".roomIds = [ "!cEgfyfEHPMQGtNliqC:ocf.io" ];
      "#introduce-yourself".roomIds = [ "!TLkoqDXRVMyWEMXHva:ocf.io" ];
      "#rebuild".roomIds = [ "!cEgfyfEHPMQGtNliqC:ocf.io" ];
      "#off-topic".roomIds = [ "!zssQqFOjeDgMvEitnT:ocf.io" ];
      "#board-games".roomIds = [ "!dBzwYLxqHyAljomPFh:ocf.io" ];
      "#hack-day".roomIds = [ "!GPIsogWHfbpmrCMuMI:ocf.io" ];
      "#decal".roomIds = [ "!ZnSuwfpqpNFfUxrmgU:ocf.io" ];
      "#administrivia".roomIds = [ "!NXYBQyfoOVeVIlDMeJ:ocf.io" ];
      "#opstaff".roomIds = [ "!vqmIzqVlZukuyfFEpf:ocf.io" ];
    };
  };

  system.stateVersion = "25.05";
}
