@echo off
setlocal enableExtensions enableDelayedExpansion

rem --- Configuration ---------------------
set APP_NAME=dummy
set APP_DIR=dummy-app
set DOWNLOAD_URL=https://github.com/codejive/bootstrap/releases/latest/download/release.tgz
rem ---------------------------------------
rem Should we install the wrapper scripts into the user's shared bin directory?
set INSTALL_BIN=no
rem Do we enable the uninstall feature? (ie passing the single argument '__UNINSTALL' to this script)
set ENABLE_UNINSTALL=yes
rem The update period in days (e.g., 3 means check if the last_checked file is older than 3 days)
set UPDATE_PERIOD=3
rem Logging level (0-ERROR, 1-WARN, 2-INFO, 3-DEBUG, empty disables logging)
set "LOG_LEVEL=1"
rem ---------------------------------------

set "HOME_DIR=%USERPROFILE%"
set "SHARED_BIN=%HOME_DIR%\.local\bin"

goto :START

rem --- Configuration Loading ---
rem Helper subroutine to load configuration from a file
:LOAD_CONFIG
    set "CONFIG_FILE=%~1"
    if exist "%CONFIG_FILE%" (
        rem call :LOG_INFO "Loading configuration from %CONFIG_FILE%..."
        for /f "tokens=1* delims== eol=#" %%a in ('type "%CONFIG_FILE%"') do (
            set %%a=%%b
        )
    )
    goto :eof

rem Helper functions for logging
:LOG_ERROR
    if "%LOG_LEVEL%" EQU "" goto :eof
    if 0 LEQ "%LOG_LEVEL%" 2>nul (
        echo [31mERROR[0m: %~1
    )
    goto :eof

:LOG_WARN
    if "%LOG_LEVEL%" EQU "" goto :eof
    if 1 LEQ %LOG_LEVEL% 2>nul (
        echo [[33m%APPNM% WARN[0m] %~1
    )
    goto :eof

:LOG_INFO
    if "%LOG_LEVEL%" EQU "" goto :eof
    if 2 LEQ %LOG_LEVEL% 2>nul (
        echo [%APPNM% INFO] %~1
    )
    goto :eof

:UNPACK_AND_INSTALL
    set "RETURN_CODE=0"

    rem Unpack and clean up
    call :LOG_INFO "Unpacking application..."

    rem Remove existing installation directory if it exists before unpacking
    if exist "%TMP_DIR%" rmdir /s /q "%TMP_DIR%"

    rem Create a temporary directory for unpacking
    mkdir "%TMP_DIR%"

    rem Use the built-in 'tar' utility for ZIP/TAR.GZ extraction
    tar -xf "%ARCHIVE_FILE%" -C "%TMP_DIR%"
    if errorlevel 1 (
        call :LOG_ERROR "Failed to unpack archive %ARCHIVE_FILE%"
        rmdir /s /q "%TMP_DIR%"
        set "RETURN_CODE=1"
        goto :eof
    )

    rem Move all contents of temp_install to NEW_DIR
    call :LOG_INFO "Moving contents to %HAP_DIR%"
    mkdir "%APP_HOME%"
    move "%TMP_DIR%" "%NEW_DIR%" > nul

    rem Replace the old app directory with the new one atomically
    if exist "%HAP_DIR%" (
        move /Y "%HAP_DIR%" "%BAK_DIR%" > nul
        move /Y "%NEW_DIR%" "%HAP_DIR%" > nul
        rmdir /s /q "%BAK_DIR%"
    ) else (
        move /Y "%NEW_DIR%" "%HAP_DIR%" > nul
    )

    if "%INSTALL_BIN%"=="yes" (
        rem Copy application script(s) to shared bin
        if defined SHARED_BIN (
            call :LOG_INFO "Making application available in shared bin directory: %SHARED_BIN%"
            if not exist "%SHARED_BIN%" mkdir "%SHARED_BIN%"
            rem We always copy the Bash script (if it exists), even on Windows
            if exist "%APP_SCRIPT%" (
                copy /Y "%APP_SCRIPT%" "%SHARED_BIN%\%APPNM%" > nul
            )
            rem We also copy the batch file (it should exist)
            copy /Y "%APP_SCRIPT%.cmd" "%SHARED_BIN%\%APPNM%.cmd" > nul
        )

        rem Warn user when the app is not available in their PATH
        where /q "%APPNM%" 2>nul
        if errorlevel 1 (
            call :LOG_WARN "'%SHARED_BIN%' is not in your PATH. You may want to add it to run '%APPNM%' from anywhere."
        )
    )

    rem Clean up the temporary directory
    if exist "%TMP_DIR%" rmdir /s /q "%TMP_DIR%"

    call :LOG_INFO "Installation complete in %APP_HOME%"
    goto :eof

:DOWNLOAD_AND_INSTALL
    set "RETURN_CODE=0"
    set "UPDATE_NEEDED=false"

    rem Check file age: older than %UPDATE_PERIOD% days? (or doesn't exist)
    rem forfiles exits with ERRORLEVEL 0 if files matching the criteria are found.
    rem /D -N means files older than N days ago.
    forfiles /P "%CCH_DIR%" /M last_checked /D -%UPDATE_PERIOD% /C "cmd /c echo Found > nul" 2>nul
    if errorlevel 1 (
        rem ERRORLEVEL 1 means no files older than %UPDATE_PERIOD% days were found (either file is new, or file doesn't exist)
        if not exist "%LAST_CHECKED_FILE%" (
            call :LOG_INFO "Checking for updates [file missing]..."
            set "UPDATE_NEEDED=true"
        ) else (
            rem Check for files older than %UPDATE_PERIOD% days
            set "IS_OLD=false"
            forfiles /P "%CCH_DIR%" /M last_checked /D -%UPDATE_PERIOD% /C "cmd /c set IS_OLD=true" 2>nul
            if "%IS_OLD%"=="true" (
                call :LOG_INFO "Checking for updates [last check older than %UPDATE_PERIOD% days or file missing]..."
                set "UPDATE_NEEDED=true"
            ) else (
                call :LOG_INFO "Skipping update check [last check within %UPDATE_PERIOD% days]"
                goto :eof
            )
        )
    ) else (
        rem The file exists and IS older than %UPDATE_PERIOD% days, so ERRORLEVEL 0 was returned.
        call :LOG_INFO "Checking for updates [last check older than %UPDATE_PERIOD% days]..."
        set "UPDATE_NEEDED=true"
    )

    if "!UPDATE_NEEDED!" NEQ "true" (
        goto :eof
    )

    rem Setup directories
    if not exist "%CCH_DIR%" mkdir "%CCH_DIR%" || (
        call :LOG_ERROR "Could not create cache directory %CCH_DIR%"
        set "RETURN_CODE=1"
        goto :eof
    )

    rem -z "%ARCHIVE_FILE%" tells curl to only download if the remote file is newer than the local one.
    rem --remote-time (-r) ensures the new file uses the remote timestamp.
    rem Use -w "%{http_code}" to capture the status code
    set "HTTP_CODE=0"
    for /f %%i in ('curl -w "%%{http_code}" -fsSL --remote-time -z "!ARCHIVE_FILE!" "!DLURL!" -o "!ARCHIVE_FILE!"') do (
        set "HTTP_CODE=%%i"
    )
    call :LOG_INFO "Received HTTP code: !HTTP_CODE!"

    if "!HTTP_CODE!" NEQ "" (
        if !HTTP_CODE! GEQ 200 (
            if !HTTP_CODE! LSS 300 (
                call :LOG_INFO "New release downloaded"
                rem Unpack the new release
                call :UNPACK_AND_INSTALL
                goto :MARK_CHECKED
            )
        )
        if "!HTTP_CODE!" EQU "304" (
            rem Conditional download skipped (304 Not Modified)
            call :LOG_INFO "No new release available [304 Not Modified]"
        ) else (
            rem Other error or redirection
            call :LOG_INFO "Conditional download failed or returned unexpected status code: %HTTP_CODE%. Skipping update"
            set "RETURN_CODE=1"
        )
    )

:MARK_CHECKED
    rem Update last_checked timestamp regardless of success/failure of the update attempt
    type nul > "%LAST_CHECKED_FILE%"
    call :LOG_INFO "Download/update check complete"
    goto :eof

:INSTALL_APP
    call :LOG_INFO "Check for executable %APP_SCRIPT%"
    if not exist "%APP_SCRIPT%.cmd" (
        call :LOG_INFO "Application not found. Starting download and install..."
        call :DOWNLOAD_AND_INSTALL
        if "!RETURN_CODE!" NEQ "0" (
            call :LOG_ERROR "Installation of application failed!"
            (goto) 2>nul & exit /b 1
        )
    ) else (
        call :LOG_INFO "Application found. Check if there is an update to install..."
        call :DOWNLOAD_AND_INSTALL
    )
    goto :eof

:UNINSTALL_APP
    call :LOG_INFO "Uninstalling application %APPNM%..."
    rem Remove APP_HOME/bootstrap
    if exist "%HAP_DIR%" rmdir /s /q "%HAP_DIR%" >nul 2>&1
    rem Remove APP_HOME if it's now empty
    if exist "%APP_HOME%" rmdir "%APP_HOME%" >nul 2>&1
    rem Remove the application's cache folder
    if exist "%CACHE_HOME%" rmdir /s /q "%CACHE_HOME%" >nul 2>&1
    rem Remove shared bin scripts if installed
    if "%INSTALL_BIN%"=="yes" (
        if exist "%SHARED_BIN%\%APPNM%" del /f /q "%SHARED_BIN%\%APPNM%" >nul 2>&1
        if exist "%SHARED_BIN%\%APPNM%.cmd" del /f /q "%SHARED_BIN%\%APPNM%.cmd" >nul 2>&1
    )
    call :LOG_INFO "Uninstallation complete."
    goto :eof

:PERFORM
    set action=%~1
    set APPNM=%~2
    set APPDR=%~3
    set DLURL=%~4

    rem Define essential directories
    set "APP_HOME=%HOME_DIR%\.local\share\%APPDR%"
    set "CONFIG_HOME=%HOME_DIR%\.config\%APPDR%"
    set "CACHE_HOME=%HOME_DIR%\.cache\%APPDR%"

    rem Load user-wide configuration (if exists)
    call :LOAD_CONFIG "%CONFIG_HOME%\bootstrap.cfg"

    rem Load local configuration (if exists)
    call :LOAD_CONFIG ".\.%APPDR%\bootstrap.cfg"

    rem INSTALL_BIN can be overridden by the user environment variable BS_INSTALL_BIN
    if defined BS_INSTALL_BIN set "INSTALL_BIN=%BS_INSTALL_BIN%"

    rem ENABLE_UNINSTALL can be overridden by the user environment variable BS_ENABLE_UNINSTALL
    if defined BS_ENABLE_UNINSTALL set "ENABLE_UNINSTALL=%BS_ENABLE_UNINSTALL%"

    rem LOG_LEVEL can be overridden by the user environment variable BS_LOG_LEVEL
    if defined BS_LOG_LEVEL set "LOG_LEVEL=%BS_LOG_LEVEL%"

    set "HAP_DIR=%APP_HOME%\bootstrap"
    set "BAK_DIR=%HAP_DIR%._bak_"
    set "NEW_DIR=%HAP_DIR%._new_"
    set "BIN_DIR=%HAP_DIR%\bin"
    set "CCH_DIR=%CACHE_HOME%\bootstrap"
    set "TMP_DIR=%CCH_DIR%\temp_install"
    set "APP_SCRIPT=%BIN_DIR%\%APPNM%"
    set "ARCHIVE_FILE=%CCH_DIR%\release.tgz"
    set "LAST_CHECKED_FILE=%CCH_DIR%\last_checked"

    if "%action%"=="install_app" (
        call :INSTALL_APP
    ) else if "%action%"=="uninstall_app" (
        if "%ENABLE_UNINSTALL%"=="yes" (
            call :UNINSTALL_APP
            (goto) 2>nul & exit /b 0
        )
    )

    goto :eof

:START

rem Check if uninstall was requested
if "%~1"=="__UNINSTALL" if "%~2"=="" (
    call :PERFORM "uninstall_app" "%APP_NAME%" "%APP_DIR%" "%DOWNLOAD_URL%"
)

rem Installation/Update Check
call :PERFORM "install_app" "%APP_NAME%" "%APP_DIR%" "%DOWNLOAD_URL%"

rem Execution Handover (The final requirement)
rem Check if the currently executing script is NOT the application itself
set "APP_SCRIPT=%HOME_DIR%\.local\share\%APP_DIR%\bootstrap\bin\%APP_NAME%"
set "CURRENT_SCRIPT_PATH=%~f0"
set "BIN_EXE_PATH1=%APP_SCRIPT%.cmd"
set "BIN_EXE_PATH2=%SHARED_BIN%\%APP_NAME%.cmd"

rem Check if the current script path is NOT the path of the actual application executable
if /I not "%CURRENT_SCRIPT_PATH%"=="%BIN_EXE_PATH1%" (
    if /I not "%CURRENT_SCRIPT_PATH%"=="%BIN_EXE_PATH2%" (
        call :LOG_INFO "Handing over execution to the installed application: %APP_SCRIPT%.cmd"
        "%APP_SCRIPT%.cmd" %*
        goto :eof
    )
)

rem ##########################################
rem # BELOW THIS POINT YOU PUT YOUR OWN CODE #
rem ##########################################

rem Your application's main logic or final execution step would go here if this script
rem *is* the final executable. Otherwise you can call out to other scripts or binaries as needed.

call :LOG_INFO "This would be your application."

rem For simplicity, we just print a success message and exit.
echo ------------------------------------
echo This is application: %APP_NAME%
echo Arguments received : %*
echo ------------------------------------

endlocal
exit /b 0
