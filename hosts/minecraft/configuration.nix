{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];

  system.stateVersion = "26.05";

  nixpkgs.hostPlatform.system = "aarch64-linux";

  # The Minecraft server jar is unfreeRedistributable.
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "minecraft-server";

  networking.hostName = "minecraft";

  # networkd wants a timezone set. See hosts/arianvp.me.
  time.timeZone = "Europe/Amsterdam";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # t4g.medium only has 4G of RAM; give the JVM somewhere to spill so a
  # chunk-generation spike does not get us OOM-killed mid-game.
  swapDevices = [
    {
      device = "/var/lib/swap";
      size = 4 * 1024;
    }
  ];
  systemd.oomd.enableSystemSlice = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };

  # Deploy key. This is the public half of id_ecdsa_sk_rk_claude; the private
  # half lives on the YubiKey and is never in this repo.
  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBIWaZ3n+TNPOzUvBxTJptHjOsIUQjvbz1rTTYKLTb5A+cFXeUhsFKElACQO/VMtDB9tJMjMj78DSGR6j3BfsDcgAAAAEc3NoOg== ssh:"
    "sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBLqm1oVbT+zVLwZUJYPHYtGojB8ZWqRAAX4ZekSiqCV4yXt8XCauvqrmuMYRW+nlkZ0vzhHg5AoiSmZGS7ObMUwAAAAEc3NoOg== ssh:"
  ];

  services.minecraft-server = {
    enable = true;
    eula = true;
    declarative = true;
    openFirewall = true;
    # ~2.5G heap out of 4G, leaving room for the JVM's non-heap usage and the OS.
    jvmOpts = "-Xms1024M -Xmx2560M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC";
    serverProperties = {
      motd = "Arian's server";
      difficulty = "normal";
      gamemode = "survival";
      max-players = 10;
      server-port = 25565;
      # Public server on a public IP: keep the Mojang session check on so only
      # legitimately-authenticated accounts can join.
      online-mode = true;
      white-list = false;
      spawn-protection = 0;
      view-distance = 10;
      simulation-distance = 8;
      enable-command-block = false;
    };
  };
}
