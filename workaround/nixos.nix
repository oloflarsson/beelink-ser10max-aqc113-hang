# NixOS: the same cap, persistent. Import from configuration.nix.
{ ... }:
{
  powerManagement.cpufreq.max = 4500000;
}
