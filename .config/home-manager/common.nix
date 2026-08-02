{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.kitty
    pkgs.gcc
  ];

  programs.home-manager.enable = true;
}
