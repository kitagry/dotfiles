{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.kitty
  ];

  programs.home-manager.enable = true;
}
