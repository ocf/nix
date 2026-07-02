{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [ ../../hardware/virtualized.nix ];

  # FIXME: python3.14-html5lib-1.1 and python3.14-rich-14.1.0 are broken on
  # 25.11 but not 26.05. matrix-appservice-discord is broken on 26.05 but not
  # 25.11. scootaloo needs all three of these packages, so scootaloo is on nixos
  # 25.11 with python 3.12.
  # ps dont you think that its neat that "25.11" is left aligned when i wrapped
  # this comment at 80 chars? :)
  ocf.python.package = pkgs.python312;

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
    element.url = "chat.ocf.io";
    irc-bridge.enable = true;
    irc-bridge.server = "irc.ocf.io";

    initialRooms = [
      # right click channel in discord, "Copy Channel ID"
      # first make channels on discord, then bridge to matrix, then finally bridge to irc
      "#_discord_735620315111096391_761065162450272286:ocf.io" # opstaff
      "#_discord_735620315111096391_735624339847643277:ocf.io" # administrivia
      "#_discord_735620315111096391_736066924592758785:ocf.io" # decal
      "#_discord_735620315111096391_833090052996857876:ocf.io" # hack-day
      "#_discord_735620315111096391_1012214233322246214:ocf.io" # board-games
      "#_discord_735620315111096391_735624292179640331:ocf.io" # off-topic
      "#_discord_735620315111096391_735624203860181135:ocf.io" # rebuild
      "#_discord_735620315111096391_881325795044368414:ocf.io" # introduce-yourself
      "#_discord_735620315111096391_736005105068802109:ocf.io" # announcements
      "#_discord_735620315111096391_1288710167633985536:ocf.io" # design
    ];

    irc-bridge.initialRooms = {
      # room ID: log onto matrix, right-click channel, click settings, click Advanced, should see "Internal room ID" section
      "#announcements".roomIds = [ "!aOxFvQVvHZsjmmZFaG:ocf.io" ];
      "#introduce-yourself".roomIds = [ "!TLkoqDXRVMyWEMXHva:ocf.io" ];
      "#rebuild".roomIds = [ "!cEgfyfEHPMQGtNliqC:ocf.io" ];
      "#off-topic".roomIds = [ "!zssQqFOjeDgMvEitnT:ocf.io" ];
      "#board-games".roomIds = [ "!dBzwYLxqHyAljomPFh:ocf.io" ];
      "#hack-day".roomIds = [ "!GPIsogWHfbpmrCMuMI:ocf.io" ];
      "#decal".roomIds = [ "!ZnSuwfpqpNFfUxrmgU:ocf.io" ];
      "#administrivia".roomIds = [ "!NXYBQyfoOVeVIlDMeJ:ocf.io" ];
      "#opstaff".roomIds = [ "!vqmIzqVlZukuyfFEpf:ocf.io" ];
      "#design".roomIds = [ "!dmmQVQBHkHDuDCrsNv:ocf.io" ];
    };
  };

  system.stateVersion = "25.05";
}
