{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.kitty
    pkgs.gcc
    pkgs.wl-clipboard
    pkgs.nodejs
    pkgs.jq
  ];

  programs.home-manager.enable = true;
}
