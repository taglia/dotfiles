{ config, ... }:

{
  programs.atuin.settings = {
    auto_sync = true;
    sync_frequency = "5m";
  };
}
