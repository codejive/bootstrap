# Bootstrap Wrapper Demo

This directory contains a minimal dummy application used only to demonstrate how the bootstrap wrapper scripts work.

## Purpose
The files here are not a real application. They are only copies of the wrapper scripts from the root folder edited to act as a example application called `dummy`. The purpose is to illustrate how the wrapper scripts function in an imagined real-world scenario. It shows:
- How the wrapper scripts can be named differently than the application they wrap.
- How the release archive structure looks like.
- How the configuration file for the bootstrapper can be used to change the default behavior (in this case, setting the log level to `DEBUG` for demonstration purposes).

## Contents
- `dummyw` — Unix-style wrapper script. Showing that it can be named differently than the application it wraps.
- `dummyw.cmd` — The same wrapper script but for Windows
- `release/` — The contents of the release archive that the wrapper scripts would download and install
- `release/bin/dummy` — A duplicate of the unix-style wrapper script, but using the application's actual name
- `release/bin/dummy.cmd` — Also a duplicate, but for Windows
- `.dummy-app/bootstrap.cfg` — Configuration file for the bootstrapper, set to log at `DEBUG` level for demonstration purposes

## Usage (Linux/Mac)
1. Open a terminal.
2. Change directory to this folder: `cd dummy-app`
3. Run the wrapper: `./dummyw`
    - The wrapper will proceed to download and install the application (if not already installed) and then locate and invoke the installed `dummy` script. The output will look something like this:
    ```
    $ ./dummyw aap noot mies
    [dummy INFO] Check for executable /c/Users/demo/.local/share/dummy-app/bootstrap/bin/dummy
    [dummy INFO] Application not found. Starting download and install...
    [dummy INFO] Checking for updates [last check older than 3 days or file missing]...
    [dummy INFO] Received HTTP code: 200
    [dummy INFO] New release downloaded
    [dummy INFO] Unpacking application...
    [dummy INFO] Moving contents to /c/Users/demo/.local/share/dummy-app/bootstrap
    [dummy INFO] Making application available in shared bin directory: /c/Users/demo/.local/bin
    [dummy WARN] '/c/Users/demo/.local/bin' is not in your PATH. You may want to add it to run 'dummy' from anywhere.
    [dummy INFO] Installation complete in /c/Users/demo/.local/share/dummy-app
    [dummy INFO] Handing over execution to the installed application: /c/Users/demo/.local/share/dummy-app/bootstrap/bin/dummy
    [dummy INFO] Check for executable /c/Users/demo/.local/share/dummy-app/bootstrap/bin/dummy
    [dummy INFO] Application found. Check if there is an update to install...
    [dummy INFO] Skipping update check [last check within 3 days]
    [dummy INFO] Running inside the application's environment [/c/Users/demo/.local/share/dummy-app/bootstrap/bin]
    ------------------------------------
    This is application: dummy
    Arguments received : aap noot mies
    ------------------------------------
    ```
    - The output is very "chatty" because for demonstration purposes the `boostrap.cfg` file in the `.dummy-app` folder has been created to set the log level to `DEBUG`.
   

## Usage (Windows)
1. Open Command Prompt or PowerShell.
2. Change directory to this folder: `cd dummy-app`
3. Run the wrapper: `.\dummyw.cmd`
   - The wrapper will proceed to download and install the application (if not already installed) and then locate and invoke the installed `dummy.cmd` script. The output will look something like this:
    ```
    > .\dummyw aap noot mies
    [dummy INFO] Check for executable C:\Users\demo\.local\share\dummy-app\bootstrap\bin\dummy
    [dummy INFO] Application not found. Starting download and install...
    [dummy INFO] Checking for updates [file missing]...
    [dummy INFO] Received HTTP code: 200
    [dummy INFO] New release downloaded
    [dummy INFO] Unpacking application...
    [dummy INFO] Moving contents to C:\Users\demo\.local\share\dummy-app\bootstrap
    [dummy INFO] Making application available in shared bin directory: C:\Users\demo\.local\bin
    [dummy WARN] 'C:\Users\demo\.local\bin' is not in your PATH. You may want to add it to run 'dummy' from anywhere.
    [dummy INFO] Installation complete in C:\Users\demo\.local\share\dummy-app
    [dummy INFO] Download/update check complete
    [dummy INFO] Handing over execution to the installed application: C:\Users\demo\.local\share\dummy-app\bootstrap\bin\dummy.cmd
    [dummy INFO] Check for executable C:\Users\demo\.local\share\dummy-app\bootstrap\bin\dummy
    [dummy INFO] Application found. Check if there is an update to install...
    [dummy INFO] Skipping update check [last check within 3 days]
    [dummy INFO] Running inside the application's environment [C:\Users\demo\.local\share\dummy-app\bootstrap\bin]
    ------------------------------------
    This is application: dummy
    Arguments received : aap noot mies
    ------------------------------------
    ```
   - The output is very "chatty" because for demonstration purposes the `boostrap.cfg` file in the `.dummy-app` folder has been created to set the log level to `DEBUG`.

## Notes
- The scripts are examples only; they show common bootstrap behaviors (path resolution, argument forwarding, minimal environment setup).
