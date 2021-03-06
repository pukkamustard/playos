{ config, pkgs, lib, ... }:
{

  # Kiosk runs as a non-privileged user
  users.users.play = {
    isNormalUser = true;
    home = "/home/play";
    # who can play audio.
    extraGroups = [ "audio" ];
  };

  # Note that setting up "/home" as persistent fails due to https://github.com/NixOS/nixpkgs/issues/6481
  volatileRoot.persistentFolders."/home/play" = {
    mode = "0700";
    user = "play";
    group = "users";
  };

  # Kiosk session
  services.xserver = {
    enable = true;

    desktopManager = {
      xterm.enable = false;
      # "Boot to Gecko"
      default = "chromium-kiosk";
      session = [
        { name = "chromium-kiosk";
          start = ''
            # Disable screen-saver control (screen blanking)
            xset s off

            # chromium sometimes fails to load properly if immediately started
            sleep 1
            # --window-size is a hack, see here: https://unix.stackexchange.com/questions/273989/how-can-i-make-chromium-start-full-screen-under-x
            ${pkgs.chromium}/bin/chromium \
              --no-sandbox \
              --no-first-run \
              --noerrdialogs \
              --start-fullscreen \
              --start-maximized \
              --window-size=9000,9000 \
              --disable-notifications \
              --disable-infobars \
              --disable-save-password-bubble \
              --autoplay-policy=no-user-gesture-required \
              --kiosk https://play.dividat.com/
            waitPID=$!
          '';
        }
      ];
    };

    displayManager = {
      # Always automatically log in play user
      lightdm = {
        enable = true;
        greeter.enable = false;
        autoLogin = {
          enable = true;
          user = "play";
          timeout = 0;
        };
      };
    };
  };

  # Driver service
  systemd.services."dividat-driver" = {
    description = "Dividat Driver";
    serviceConfig.ExecStart = "${pkgs.dividat-driver}/bin/dividat-driver";
    serviceConfig.User = "play";
    wantedBy = [ "multi-user.target" ];
  };

  # Enable audio
  hardware.pulseaudio.enable = true;

  # Run PulseAudio as System-Wide daemon. See [1] for why this is in general a bad idea, but ok for our case.
  # [1] https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/WhatIsWrongWithSystemWide/
  hardware.pulseaudio.systemWide = true;

  # Install a command line mixer
  # TODO: remove when controlling audio works trough controller
  environment.systemPackages = with pkgs; [ pamix pamixer ];

  # Enable avahi for Senso discovery
  services.avahi.enable = true;

  # Enable pcscd for smart card identification
  services.pcscd.enable = true;

}
