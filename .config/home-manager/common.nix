{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.kitty
    pkgs.gcc
    pkgs.wl-clipboard
    pkgs.nodejs
    pkgs.python3
    pkgs.jq
    pkgs.gnumake
  ];

  programs.home-manager.enable = true;

  # Disable GNOME's automatic suspend on AC power so the machine stays
  # reachable as an always-on server (e.g. Claude Code from a phone).
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
  };
}
