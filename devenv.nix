{ pkgs
, ...
}:
{
  packages = with pkgs; [
    _1password
    azure-cli
    jq
    opentofu
    terragrunt
  ];
}
