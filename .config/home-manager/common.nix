{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.kitty
    pkgs.gcc
    pkgs.wl-clipboard
  ];

  programs.home-manager.enable = true;
}
