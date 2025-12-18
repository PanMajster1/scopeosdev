# Building ScopeOS

ScopeOS is a custom Ubuntu 24.04-based distribution featuring a theme switcher (MacOS, Windows, etc.), enhanced privacy, and the Calamares installer.

## Prerequisites

- A computer running Linux (Ubuntu recommended).
- **Cubic** (Custom Ubuntu ISO Creator) installed:
  ```bash
  sudo apt-add-repository ppa:cubicsystem/cubic
  sudo apt update
  sudo apt install cubic
  ```
- An **Ubuntu 24.04 LTS ISO** file.

## Build Instructions

1.  **Start Cubic:**
    - Open Cubic and select your workspace directory.
    - Select the original Ubuntu 24.04 ISO.
    - Click "Next" until you reach the Terminal screen (the chroot environment).

2.  **Copy Files:**
    - You need to get the files from this repository into the Cubic environment.
    - In the Cubic window, drag and drop the `scopeos/` folder from your file manager onto the terminal area. It usually copies them to `/home/custom/scopeos` or similar.
    - Alternatively, install git inside Cubic and clone this repo:
      ```bash
      apt update && apt install git
      git clone https://github.com/PanMajster1/scopeosdev.git /opt
      ```

3.  **Run the Preparation Script:**
    - Navigate to the scripts directory and run the master script:
      ```bash
      cd /opt/scopeos/scripts
      chmod +x prepare_scopeos_env.sh
      ./prepare_scopeos_env.sh
      ```
    - *Note:* Ensure you have internet access inside Cubic.

4.  **Finish Building:**
    - Once the script finishes, click "Next" in Cubic.
    - Select the kernel (usually default).
    - Select compression (gzip or xz).
    - Click "Generate".

5.  **Result:**
    - You will have a `scopeos.iso` file ready to burn to USB or test in a VM.

## Architecture

- **Theme Switcher:** Located at `/usr/local/bin/scopeos-control-center`. Launchable from the app grid.
- **Installer:** Calamares is configured in `/etc/calamares`.
- **Themes:** Installed in `/usr/share/themes` and `/usr/share/icons`.
