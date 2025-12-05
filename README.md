# **Bootstrap Scripts**

**Universal Wrapper - an application installer and updater**

This repository contains two scripts: one Bash script for Linux/macOS and one Batch script for Windows, designed to manage the installation, periodic checking, and execution of a single command-line application.

The primary goal is to provide an extremely simply, user-friendly wrapper that ensures the application is always present and up-to-date before it runs, without having to rely on traditional package managers.

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

| Variable         | Default Value (Example)   | Description                                                                              |
|:-----------------|:--------------------------|:-----------------------------------------------------------------------------------------|
| **APP_NAME**     | `APP`                     | The short name of the application.                                                       |
| **APP_DIR**      | `.APP`                    | The installation directory name of the application.                                      |
| **DOWNLOAD_URL** | `https://example.com/...` | The direct download URL for the release archive (.tgz for Bash, .zip or .tgz for Batch). |

### **2\. Overridable Variables**

These variables have defaults set within the script but can be overridden by placing them in one of the following configuration files (in order of precedence):

1. `$HOME/<APP_DIR>/bootstrap.cfg` (User-wide defaults)
2. `./<APP_DIR>/bootstrap.cfg` (Local overrides)

The format for the configuration files is simple `KEY=VALUE`, with comments starting with `#`.

| Variable          | Default Value | Description                                                                                                                                                           |
|:------------------|:--------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **UPDATE_PERIOD** | 3             | The number of days after which an update check must be performed. If the last\_checked file is older than this period, the script will attempt to contact the server. |
| **LOG_LEVEL**     | \<empty>      | Logging level. Default empty/silent; set to anything, e.g., 'DEBUG', to enable logging                                                                               |

**Example bootstrap.cfg content:**

```
# Configuration to override the default update period  
UPDATE_PERIOD=7

# You can add other configurations here later  
# LOG_LEVEL=DEBUG
```

## **Script Details**

### **`APP` (Linux/macOS)**

* **Requirements:** `bash`, `curl`, `tar`, `find` and `stat`.

### **`APP.cmd` (Windows)**

* **Requirements:** Modern Windows (10/11) with `curl` and `tar` available in the PATH.

## **Preparation**

You will need a hosting location for your application’s release archive (a `.tgz` file for the Bash script, and a `.zip` or `.tgz` file for the Batch script). This archive can contain any files you want but it should have at least the two script files in a `bin` folder.
This is the minimum contents of the archive:

```
bin/
  APP
  APP.cmd
```

but you can also include additional files and folders as needed. The following is an example of a more complete archive structure:

```
bin/
  APP
  APP.cmd
  other_executable_files
lib/
  supporting_libraries
docs/
  documentation_files
README.md
```

**IMPORTANT:**
1. **Permissions:** Ensure that the `APP` file inside the `bin` folder has executable permissions set (especially for Linux/macOS).
2. **Naming:** It is required that scripts in the `bin` are named the same as the variable `NAME` found inside them (see [Usage](#usage) below).
3. **No conflicts:** Do _not_ include the `bootstrap.cfg` file inside the archive, as it would override user configurations on each update. And no folder or file named `_cache` should exist either.

### **Uploading**

1. **Configure:** Edit the `NAME` and `DOWNLOAD_URL` variables (and possibly `APP_DIR` if you want a different name than the default) at the top of both scripts (`APP` and `APP.bat`).
2. **Rename:** Rename the scripts to match your application's name.
3. **Upload:** Upload the release archive to your hosting location and ensure the `DOWNLOAD_URL` variable points to it.

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

### Force new version check

To force an update check, you can delete the `last_checked` file located in the application's installation directory, eg:

```
rm $HOME/.APP/_cache/last_checked
```

Then the next execution of the script will check for updates.

### Force update/reinstall

To force a complete reinstallation of the application, delete the application's `cache` directory, eg:

```
rm -rf $HOME/.APP/_cache
```

Then the next execution of the script will download and install the application afresh.
