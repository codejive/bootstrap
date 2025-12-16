# **Bootstrap Scripts**

**Universal Wrapper - an application installer and updater**

This repository contains two scripts: one Bash script for Linux/macOS and one Batch script for Windows, designed to manage the installation, periodic checking, and execution of a single command-line application.

The primary goal is to provide an extremely simply, user-friendly copy&pastable wrapper script that ensures the application is always present and up-to-date before it runs, without having to rely on traditional package managers.

## **Features**

These scripts handle the following responsibilities:

1. **First-Time Installation:** If the application is not found, it performs a complete download and unpacks the binary into the user’s `$HOME/.local/share` directory.
2. **Conditional Updates:** It checks for updates conditionally. If the local file is older than the remote one, it downloads and unpacks the new version, minimizing unnecessary data transfer.
3. **Lazy Update Checking:** It only checks the remote server for updates if the last check was done after the configured time period has passed (default is 3 days).
4. **Execution Handover:** The script acts as a self-installer/updater wrapper. After ensuring the application is ready, it hands over execution to the application to be started.
5. **Configuration Overrides:** Key variables, like the update frequency, can be configured without editing the main script file.
6. **Uninstall:** There is a rudimentary uninstall mechanism that can be optionally enabled.

## **Non-Features**

These scripts do not handle:

1. **PATH Modification:** They do not modify the system `PATH` or environment variables. The scripts are always copied to the user bin directory `$HOME/.local/bin` which for Linux and Mac is most likely already on the user's `PATH`, but for Windows this is unlikely to be the case. So the user must either add that bin directory to their `PATH` manually or run the script from its installed location.
2. **Dependency Management:** They do not install or manage dependencies for the application. It is assumed all required dependencies are part of the application package or already present on the system.
3. **Complex Versioning:** They do not manage complex versioning schemes. The update check is based solely on file modification timestamps obtained from the download URL.
4. **Multi-User Installations:** The installation is per-user and does not support system-wide installations.

## **Configuration**

Configuration is managed in two ways:

### **1\. Hardcoded Variables (Non-Overridable)**

These variables are defined directly at the top of the scripts and **should not** be overridden by bootstrap.cfg.

| Variable         | Default Value (Example)   | Description                                                                              |
|:-----------------|:--------------------------|:-----------------------------------------------------------------------------------------|
| **APP_NAME**     | `RENAME_ME`               | The short name of the application.                                                       |
| **APP_DIR**      | `RENAME_ME`               | The installation directory name of the application.                                      |
| **DOWNLOAD_URL** | `https://example.com/...` | The direct download URL for the release archive (.tgz for Bash, .zip or .tgz for Batch). |

### **2\. Overridable Variables**

These variables have defaults set within the script but can be overridden by placing them in one of the following configuration files (in order of precedence):

1. `$HOME/.config/<APP_DIR>/bootstrap.cfg` (User-wide defaults)
2. `./.<APP_DIR>/bootstrap.cfg` (Local overrides)

The format for the configuration files is simple `KEY=VALUE`, with comments starting with `#`.

| Variable             | Default Value | Description                                                                                                                                                                                                         |
|:---------------------|:--------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **INSTALL_BIN**      | no            | Determines if the wrapper scripts should be installed to the user's shared bin folder. Disabled by default, set to "yes" to enable. Can be temporarily overridden on the command line with `BS_INSTALL_BIN`.        |
| **ENABLE_INSTALL**   | yes           | Determines if the install feature should be enabled or not. Enabled by default, set to "no" (or anything besides "yes") to disable. Can be temporarily overridden on the command line with `BS_ENABLE_INSTALL`.     |
| **ENABLE_UNINSTALL** | yes           | Determines if the uninstall feature should be enabled or not. Enabled by default, set to "no" (or anything besides "yes") to disable. Can be temporarily overridden on the command line with `BS_ENABLE_UNINSTALL`. |
| **UPDATE_PERIOD**    | 3             | The number of days after which an update check must be performed. If the last\_checked file is older than this period, the script will attempt to contact the server.                                               |
| **LOG_LEVEL**        | 1             | Logging level. 0 = ERROR, 1 = WARN, 2 = INFO, 3 = DEBUG. Can be temporarily overridden on the command line with `BS_LOG_LEVEL`.                                                                                     |

**Example bootstrap.cfg content:**

```
# Configuration to override the default update period  
UPDATE_PERIOD=7

# You can add other configurations here later  
# LOG_LEVEL=3
```

## **Script Details**

### **`RENAME_ME` (Linux/macOS)**

* **Requirements:** `bash`, `curl`, `tar`, `find` and `stat`.

### **`RENAME_ME.cmd` (Windows)**

* **Requirements:** Modern Windows (10/11) with `curl` and `tar` available in the PATH.

## **Preparation**

You will need a hosting location for your application’s release archive (a `.tgz` file for the Bash script, and a `.zip` or `.tgz` file for the Batch script). This archive can contain any files you want, but it should have at least the two script files in a `bin` folder renamed to whatever your application is called (in this example `RENAME_ME` and `RENAME_ME.cmd` have become `myapp` and `myapp.cmd` respectively).
This is the minimum contents of the archive:

```
bin/
  myapp
  myapp.cmd
```

but you can also include additional files and folders as needed. The following is an example of a more complete archive structure:

```
bin/
  myapp
  myapp.cmd
  other_executable_files
lib/
  supporting_libraries
docs/
  documentation_files
README.md
```

**IMPORTANT:**
1. **Permissions:** Ensure that the `myapp` file inside the `bin` folder has executable permissions set (especially for Linux/macOS).
2. **Naming:** It is required that scripts in the `bin` are named the same as the variable `NAME` found inside them (see [Usage](#usage) below).

### **Uploading**

1. **Required:** Edit the `NAME`, `APP_DIR`, and `DOWNLOAD_URL` variables at the top of both scripts (`myapp` and `myapp.bat`).
2. **Configuration:** Optionally, decide if you want to keep uninstallation enabled or not (`ENABLE_UNINSTALL`) and if you want the scripts to install themselves to the user bin folder automatically (`INSTALL_BIN`).
3. **Rename:** Rename the scripts to match your application's name.
4. **Upload:** Upload the release archive to your hosting location and ensure the `DOWNLOAD_URL` variable points to it.

## **Usage**

After the preparation has been completed and the release archive has been uploaded, you can use the scripts as follows:

1. **Copy:** Take both scripts that you prepared in the previous step and make copies in any directory/project where you'd like these commands to be available without prior installation. A common usage is to have the name of the scripts end in the letter “w” to indicate they are “wrapper” scripts (e.g., if `APP_NAME=foo`, rename to `foow` and `foow.bat`).
4. **Execute:** Now simply run the script from the command line, passing any arguments you want to forward to the application:

```
# On Linux/Mac (make sure it's executable: chmod +x foow)  
./foow --some-argument

# On Windows  
.\foow.cmd /flag
```

The first time you run it, the application will download and install itself to the user’s home directory (`$HOME/$APP_DIR`). Subsequent runs will check for updates if the configured period has passed.

### **Making application globally available**

If the installation feature is enabled (`ENABLE_INSTALL=yes`), you can install the application's scripts to the user's shared bin folder (which on Linux and Mac is normally already available in the user's `PATH`) by running the script with a single `__INSTALL` argument (capital letters required!):

```# On Linux/Mac  
./foow __INSTALL

# On Windows  
.\foow.cmd __INSTALL
```

### **Uninstallation**

If the uninstallation feature is enabled (`ENABLE_UNINSTALL=yes`), you can uninstall the application by running the script with a single `__UNINSTALL` argument (capital letters required!):

```# On Linux/Mac  
./foow __UNINSTALL

# On Windows  
.\foow.cmd __UNINSTALL
```

### Force new version check

To force an update check, you can delete the `last_checked` file located in the application's cache directory, eg:

```
rm -rf $HOME/.cache/APP/bootstrap/last_checked
```

Then the next execution of the script will check for updates.

### Force update/reinstall

To force a complete reinstallation of the application, delete the `bootstrap` folder located in the application's cache directory, eg:

```
rm -rf $HOME/.cache/APP/bootstrap
```

Then the next execution of the script will download and install the application afresh.
