{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  # tsunami replacement host

  networking.hostName = "fluttershy";

  ocf.network = {
    enable = true;
    lastOctet = 130;
  };

  ocf.ssh.enable = true;

  ocf.nfs = {
    enable = true;
    mountHome = true;
    mountServices = true;
  };

  users.motd = 
    ''
      --------------------------------------------------------------------------------
                      Welcome to UC Berkeley's Open Computing Facility
                               https://www.ocf.berkeley.edu/
      --------------------------------------------------------------------------------
          Joining the OCF all-volunteer staff can be a great learning experience!
      --------------------------------------------------------------------------------

      08/28/25   OCF staff meetings are every Wednesday from 7:30-8:30 PM PST at 
                 ocf.io/meet and in person. All are welcome!

      10/07/25   The OCF public ssh server is in the process of being migrated to  
                 NixOS. The ssh.ocf.berkeley.edu domain will be changed to point to    
                 the new server on or after January 19th, 2026. Additionally, tsunami
                 will be entirely decommissioned and the tsunami.ocf.berkeley.edu       
                 domain will be changed to point to the new server on or after
                 May 15, 2026.

      ??/??/??   Meow mrrp mrow purr hiss mrrp

    '';

  system.stateVersion = "25.05";
}
