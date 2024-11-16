# **✨ BetterDiscord Auto-Update Script ✨**

This **PowerShell** script automates the entire process of installing and updating **BetterDiscord**. It takes care of everything: from ensuring required dependencies are installed to updating the BetterDiscord repository and injecting it into Discord. Sit back, relax, and let the script do the heavy lifting!

---

## **🚀 Features**

- **Automatically closes Discord** if it's running.  
- Checks for and installs **Git**, **Node.js**, and **pnpm** if they are missing.
- **Clones** the BetterDiscord repository if it's not already present.
- **Updates** the BetterDiscord repository to the latest version.
- Installs all dependencies and **builds the project**.
- Injects BetterDiscord into the Discord client.
- **Restarts Discord** with BetterDiscord fully injected.

---

## **🔧 Prerequisites**

Before running the script, ensure the following are installed on your system (the script will handle missing dependencies for you):
- **Git**
- **Node.js**
- **pnpm**

---

## **📝 Instructions**

### 1. **📥 Download the Script**
> [!IMPORTANT]  
> Download the `BetterDiscordUpdate.ps1` script from the **[GitHub repository](#)**.

---

### 2. **📂 Place the Script in a Convenient Location**
> [!CAUTION]  
> Make sure you place the script in an easily accessible directory. This ensures you can find and execute it later without hassle.

   - For easy access, place the script in:
     ```plaintext
     %USERPROFILE%\AppData\Roaming\BetterDiscord Update Script
     ```
   - This will make it simple to find and execute the script later.

---

### 3. **⚡ Create a Shortcut (Optional, but Recommended)**
> [!IMPORTANT]  
> **Creating a shortcut** to the script makes running it more convenient and accessible directly from the Start Menu.

   **Steps:**
   1. Right-click on your desktop and select **New > Shortcut**.
   2. In the location field, paste the following command:
      ```plaintext
      powershell.exe -ExecutionPolicy Bypass -File "%USERPROFILE%\AppData\Roaming\BetterDiscord Update Script\BetterDiscordUpdate.ps1"
      ```
   3. Name the shortcut (e.g., **"BetterDiscord Update"**).
   4. Click **Finish** to create the shortcut.
   5. Optionally, move the shortcut to your **Start Menu** folder:
      ```plaintext
      C:\ProgramData\Microsoft\Windows\Start Menu\Programs
      ```

   Now you can launch the script directly from your Start Menu! 🎉

---

### 4. **🏃‍♂️ Run the Script**
> [!IMPORTANT]  
> If you created a shortcut, you can simply click on it to run the script.

> [!CAUTION]  
> If you didn't create a shortcut, be sure to run the script **with Administrator privileges** to avoid permission issues.

   - **With Shortcut**: Simply click the shortcut you created to run the script.
   - **Without Shortcut**:
     1. Open **PowerShell** as Administrator.
     2. Navigate to the folder where the script is saved.
     3. Run the script:
        ```powershell
        .\BetterDiscordUpdate.ps1
        ```
   - Or right-click the script and select **Run with PowerShell**.

---

### 5. **🛠 What the Script Does**

> [!IMPORTANT]  
> The script takes care of **everything**. Once you run it, you don't need to worry about anything else. Here's what happens:

1. **Closes Discord** if it's running to ensure a clean update.
2. Installs **Git**, **Node.js**, and **pnpm** if they're missing.
3. **Clones** the BetterDiscord repository if it doesn’t exist.
4. **Updates** the BetterDiscord repository to the latest version.
5. Installs **dependencies** using pnpm and **builds** the project.
6. **Injects** BetterDiscord into Discord.
7. **Restarts Discord** with BetterDiscord injected!

---

### 6. **🔄 Re-running the Script**

> [!CAUTION]  
> **Re-running** the script will update BetterDiscord to the latest version, so make sure to use it whenever you want to stay up to date.

If you need to **update BetterDiscord** in the future, just rerun the script. It will handle everything automatically! 🎉

---

## **⚠️ Troubleshooting**

> [!CAUTION]  
> If the script doesn't work as expected, follow these steps to resolve common issues:

- **Dependencies Not Installing**:  
  Ensure your internet connection is stable and no firewall is blocking downloads.  
- **Discord Not Launching**:  
  If Discord doesn't restart automatically, **manually open Discord** from your desktop or Start Menu.  
- **Permission Issues**:  
  If you're facing permission issues, ensure you're running PowerShell as **Administrator**.

---

## **📄 License**

This project is licensed under the **MIT License**. Feel free to use and modify it as you wish!

---

## **🔗 Additional Links**

- [BetterDiscord Official Repository](https://github.com/BetterDiscord/BetterDiscord)  
- [PowerShell Documentation](https://learn.microsoft.com/en-us/powershell/)
