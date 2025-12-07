
{

  # TODO: Upstream sets watchdog. NixOS doesn't.
  # Again the problem is that NixOS sucks
  virtualisation.containers.enable = true;
  virtualisation.cri-o.enable = true;
  virtualisation.podman.enable = true;


  # TODO: The upstream module unconditionally pollutes /etc/cni.d
  # https://github.com/NixOS/nixpkgs/blob/dda3dcd3fe03e991015e9a74b22d35950f264a54/nixos/modules/virtualisation/cri-o.nix#L151-L154
  # https://github.com/NixOS/nixpkgs/issues/406296
}
