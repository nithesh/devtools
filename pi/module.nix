# Internal module - register pi-unwrapped and default pi package
{config, ...}: {
  perSystem = {
    system,
    pkgs,
    inputs',
    ...
  }: let
    pi-unwrapped = inputs'.llm-agents.packages.pi;
  in {
    # Unmodified upstream pi package
    packages.pi-unwrapped = pi-unwrapped;
    
    # Default pi package (unwrapped, for devShell usage)
    packages.pi = pi-unwrapped;
  };
}