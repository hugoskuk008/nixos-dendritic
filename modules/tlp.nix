{...}: {

flake.modules.nixos.tlp = {pkgs, ...}: {

  serivces.tlp = {
    enable = true;
    settings = {
      TLP_DISABLE_DEFAULTS = 1;
      TLP_WARN_LEVEL = 3;
      TLP_AUTO_SWITCH = 2;

      TLP_PROFILE_AC= "BAL";
      TLP_PROFILE_BAT = "SAV";
      TLP_PS_IGNORE = "BAT";

      DISK_IDLE_SECS_ON_AC = 0;
      DISK_IDLE_SECS_ON_BAT=2;

      CPU_DRIVER_OPMODE_ON_AC="guided";
      CPU_DRIVER_OPMODE_ON_BAT="guided";
      CPU_DRIVER_OPMODE_ON_SAV="guided";

      CPU_SCALING_GOVERNOR_ON_AC="performance";
      CPU_SCALING_GOVERNOR_ON_BAT="powersave";
      CPU_SCALING_GOVERNOR_ON_SAV="powersave";

      CPU_SCALING_MIN_FREQ_ON_SAV=624477;
      CPU_SCALING_MAX_FREQ_ON_SAV=624477;

      CPU_SCALING_MIN_FREQ_ON_BAT=624477;
      CPU_SCALING_MAX_FREQ_ON_BAT=2000000;
      
      CPU_SCALING_MIN_FREQ_ON_AC=624477;
      CPU_SCALING_MAX_FREQ_ON_AC=5000000;
      
      CPU_ENERGY_PERF_POLICY_ON_SAV = "power";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";

      CPU_BOOST_ON_AC=1;
      CPU_BOOST_ON_BAT=0;
      CPU_BOOST_ON_SAV=0;
      
      PLATFORM_PROFILE_ON_AC="performance";
      PLATFORM_PROFILE_ON_BAT="balanced";
      PLATFORM_PROFILE_ON_SAV="low-power";

      MEM_SLEEP_ON_AC="s2idle";
      MEM_SLEEP_ON_BAT="deep";

      AHCI_RUNTIME_PM_ON_BAT = "auto";
      AHCI_RUNTIME_PM_ON_AC = "on";

      RADEON_DPM_PERF_LEVEL_ON_BAT="auto";
      RADEON_DPM_PERF_LEVEL_ON_SAV="low";

      WIFI_PWR_ON_AC="off";
      WIFI_PWR_ON_BAT="on";

      WOL_DISABLE="Y";

      SOUND_POWER_SAVE_ON_AC=0;
      SOUND_POWER_SAVE_ON_BAT=10;

      PCIE_ASPM_ON_AC="default";
      PCIE_ASPM_ON_BAT="default";
      PCIE_ASPM_ON_SAV="powersupersave";

      RUNTIME_PM_ON_AC="on";
      RUNTIME_PM_ON_BAT="auto";

      USB_AUTOSUSPEND = 1;

      DEVICES_TO_DISABLE_ON_STARTUP="nfc wwan";

      DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE="bluetooth nfc wifi wwan";







      };
    };
  };
}
