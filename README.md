# BetterDiscord Auto-Update Script

This PowerShell script automates the installation and updating of BetterDiscord. It ensures all necessary dependencies are installed, updates the BetterDiscord repository, and injects BetterDiscord into Discord.

## Features
- Automatically closes Discord if it is running.
- Checks for and installs **Git**, **Node.js**, and **pnpm** if they are not already installed.
- Clones the BetterDiscord repository if it does not exist.
- Updates the BetterDiscord repository to the latest version.
- Installs dependencies and builds the project.
- Injects BetterDiscord into the Discord client.
- Restarts Discord with BetterDiscord injected.

## Prerequisites
Before running the script, ensure the following software is installed on your system. The script will check for and install missing dependencies automatically:
- **Git**
- **Node.js**
- **pnpm**

## Instructions

### 1. **Download the Script**
   - Download the `BetterDiscordUpdate.ps1` script to your computer from the GitHub repository.

### 2. **Place the Script in a Convenient Location**
   - For easy access, place the script in the following directory:
     ```plaintext
     %USERPROFILE%\AppData\Roaming\BetterDiscord Update Script
     ```
   - This will make it easy to find and run the script later.

### 3. **Create a Shortcut (Optional but Recommended)**
   - To make running the script even easier, you can create a shortcut that launches the script directly from the Start Menu.
   
   **Steps to create a shortcut:**
   1. Right-click on your desktop and select **New > Shortcut**.
   2. In the location field, paste the following command:
      ```plaintext
      powershell.exe -ExecutionPolicy Bypass -File "%USERPROFILE%\AppData\Roaming\BetterDiscord Update Script\BetterDiscordUpdate.ps1"
      ```
   3. Name the shortcut (e.g., "BetterDiscord Update").
   4. Click **Finish** to create the shortcut.
   5. Optionally, move the shortcut to your Start Menu folder:
      ```plaintext
      C:\ProgramData\Microsoft\Windows\Start Menu\Programs
      ```

   You can now launch the script directly from the Start Menu.

### 4. **Run the Script**
   - If you created a shortcut, simply click on it to run the script.
   - If you prefer to run the script manually:
     1. Open **PowerShell** as Administrator.
     2. Navigate to the folder where the script is saved.
     3. Run the script with the following command:
        ```powershell
        .\BetterDiscordUpdate.ps1
        ```
   - Alternatively, you can right-click the script file and select **Run with PowerShell**.

### 5. **What the Script Does**
   - If Discord is running, it will be closed automatically.
   - The script checks for and installs Git, Node.js, and pnpm if they are not already installed.
   - If the BetterDiscord folder is not present, it will be cloned from the official BetterDiscord GitHub repository.
   - The repository will be updated to the latest version.
   - Dependencies will be installed using pnpm, and the project will be built.
   - BetterDiscord will be injected into Discord.
   - Discord will be restarted with BetterDiscord injected.

### 6. **Re-running the Script**
   - If you need to update BetterDiscord in the future, simply re-run the script following the steps above. The script will handle the update process automatically.

## Troubleshooting

- **Dependencies Not Installing**: If the script fails to install Git, Node.js, or pnpm, check your internet connection and ensure that there are no firewalls blocking the download.
- **Discord Not Launching**: If Discord doesn't restart automatically after the script completes, manually open Discord from your desktop or Start Menu.
- **Permission Issues**: If you encounter permission issues while running the script, make sure you're running PowerShell as Administrator.

## License

This project is licensed under the MIT License.
