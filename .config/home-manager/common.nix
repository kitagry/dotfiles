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
}
