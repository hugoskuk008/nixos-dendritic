{ ... }: {
  flake.modules.nixos.tlp = { lib, ... }: {
    services.power-profiles-daemon.enable = lib.mkForce false;

    services.tlp = {
      enable = true;
      settings = {
        TLP_DISABLE_DEFAULTS = 1;
        TLP_WARN_LEVEL = 3;
        TLP_AUTO_SWITCH = 2;

        TLP_DEFAULT_MODE = "BAT";
        TLP_PERSISTENT_DEFAULT = 0;
        TLP_PROFILE_AC = "PRF";
        TLP_PROFILE_BAT = "SAV";
        TLP_PS_IGNORE = "USB";

        CPU_DRIVER_OPMODE_ON_AC = "active";
        CPU_DRIVER_OPMODE_ON_BAT = "active";
        CPU_DRIVER_OPMODE_ON_SAV = "active";

        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_SCALING_GOVERNOR_ON_SAV = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
        CPU_ENERGY_PERF_POLICY_ON_SAV = "power";

        CPU_SCALING_MIN_FREQ_ON_AC = 623377;
        CPU_SCALING_MAX_FREQ_ON_AC = 5090910;
        CPU_SCALING_MIN_FREQ_ON_BAT = 623377;
        CPU_SCALING_MAX_FREQ_ON_BAT = 2000000;
        CPU_SCALING_MIN_FREQ_ON_SAV = 623377;
        CPU_SCALING_MAX_FREQ_ON_SAV = 1200000;

        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        CPU_BOOST_ON_SAV = 0;

        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "balanced";
        PLATFORM_PROFILE_ON_SAV = "quiet";

        # GPU (amdgpu display power saving, 0-4)
        AMDGPU_ABM_LEVEL_ON_AC = 0;
        AMDGPU_ABM_LEVEL_ON_BAT = 1;
        AMDGPU_ABM_LEVEL_ON_SAV = 3;

        # PCIe / runtime PM
        PCIE_ASPM_ON_AC = "default";
        PCIE_ASPM_ON_BAT = "default";
        PCIE_ASPM_ON_SAV = "powersupersave";

        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "auto";
        RUNTIME_PM_ON_SAV = "auto";

        # Misc
        USB_AUTOSUSPEND = 1;
        NMI_WATCHDOG = 0;

        SOUND_POWER_SAVE_ON_AC = 0;
        SOUND_POWER_SAVE_ON_BAT = 10;
        SOUND_POWER_SAVE_ON_SAV = 10;
        SOUND_POWER_SAVE_CONTROLLER = "Y";

        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";
        WIFI_PWR_ON_SAV = "on";

        WOL_DISABLE = "Y";

        DEVICES_TO_DISABLE_ON_STARTUP = "nfc wwan";
        DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "bluetooth nfc wwan";
      };
    };
  };
}
