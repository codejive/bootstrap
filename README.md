# **Bootstrap Scripts**

**Universal Application Installer and Updater Scripts**

This repository contains two scripts—one Bash script for Linux/macOS and one Batch script for Windows—designed to manage the installation, periodic checking, and execution of a single command-line application.

The primary goal is to provide a user-friendly wrapper that ensures the application is always present and up-to-date before it runs, without relying on traditional package managers.

## **Features**

These scripts handle the following responsibilities:

1. **First-Time Installation:** If the application is not found, it performs a complete download and unpacks the binary into a hidden application directory in the user’s home directory.
2. **Conditional Updates:** It checks for updates conditionally. If the local file is older than the remote one, it downloads and unpacks the new version, minimizing unnecessary data transfer.
3. **Lazy Update Checking:** It only checks the remote server for updates if the last check was done after the configured time period has passed (default is 3 days).
4. **Execution Handover:** The script acts as a self-installer/updater wrapper. After ensuring the application is ready, it hands over execution to the application to be started.
5. **Configuration Overrides:** Key variables, like the update frequency, can be configured without editing the main script file.

## **Configuration**

Configuration is managed in two ways:

### **1\. Hardcoded Variables (Non-Overridable)**

These variables are defined directly at the top of the scripts and **should not** be overridden by bootstrap.cfg.

| Variable         | Default Value (Example) | Description                                                                      |
|:-----------------|:------------------------|:---------------------------------------------------------------------------------|
| **NAME**         | APP                     | The short name of the application.                                               |
| **APP_HOME**     | ~/.APP                  | The installation directory of the application.                              |
| **RELEASE_URL** | https://example.com/... | The direct download URL for the release archive (.tgz for Bash, .zip for Batch). |

### **2\. Overridable Variables**

These variables have defaults set within the script but can be overridden by placing them in one of the following configuration files (in order of precedence):

1. `$HOME/.\<NAME\>/bootstrap.cfg` (User-wide defaults)
2. `./.\<NAME\>/bootstrap.cfg` (Folder-specific overrides)

The format for the configuration files is simple KEY=VALUE, with comments starting with \#.

| Variable          | Default Value | Description |
|:------------------| :---- | :---- |
| **UPDATE_PERIOD** | 3 | The number of days after which an update check must be performed. If the last\_checked file is older than this period, the script will attempt to contact the server. |

**Example bootstrap.cfg content:**

```
# Configuration to override the default update period  
UPDATE_PERIOD=7

# You can add other configurations here later  
# LOG_LEVEL=DEBUG
```

## **Script Details**

### **`APPw` (Linux/macOS)**

* **Requirements:** `bash`, `curl`, `tar`, `find` and `stat`.

### **`APPw.cmd` (Windows)**

* **Requirements:** Modern Windows (10/11) with `curl` and `tar` available in the PATH.

## **Usage**

1. **Configure:** Edit the `NAME` and `RELEASE_URL` variables (and possibly `APP_HOME` if you want a different name than the default) at the top of both scripts (`APPw` and `APPw.bat`).
2. **Rename & Place:** Rename the scripts to match your application's name. Common usage is to have the name of the scripts end in the letter “w” to indicate they are “wrapper” scripts (e.g., if NAME=foo, rename to foow and foow.bat).
3. **Execute:** Place the scripts in a directory where you want the command to be available and run it:

```
# On Linux/Mac (make sure it's executable: chmod +x APPw)  
./foow --some-argument

# On Windows  
.\foow.cmd /flag
```

The first time you run it, the application will download and install itself to the user’s home directory ($HOME/.foo). Subsequent runs will check for updates if the configured period has passed.