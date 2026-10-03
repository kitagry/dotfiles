{ config, pkgs, lib, ... }:

let
  # claude-code in nixos-26.05 is pinned at 2.1.223, which is too old to select
  # the newer models (they need 2.1.280+), so take just this one package from
  # unstable. Machines sharing this file need the channel registered first:
  #   nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs-unstable
  #   nix-channel --update nixpkgs-unstable
  unstable = import <nixpkgs-unstable> {
    config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"
      ];
  };
in
{
  # Allow only the unfree packages listed here, so an unfree dependency never
  # slips in unnoticed on the other machines sharing this file.
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  home.packages = [
    pkgs.kitty
    pkgs.gcc
    pkgs.wl-clipboard
    pkgs.nodejs
    pkgs.python3
    pkgs.jq
    pkgs.gnumake
    # Managed here rather than in systemPackages: updating needs no sudo, and
    # it avoids mixing up the root and user nix channels.
    unstable.claude-code
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
