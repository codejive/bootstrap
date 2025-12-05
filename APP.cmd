@echo off
setlocal enableExtensions enableDelayedExpansion

rem --- Configuration (Non-Overridable) ---
set APP_NAME=APP
set APP_DIR=.APP
set DOWNLOAD_URL=https://example.com/releases/.../foo-latest.zip
rem ---------------------------------------

rem Setup essential variables needed for config loading
set "HOME_DIR=%USERPROFILE%"
set "APP_HOME=%HOME_DIR%\%APP_DIR%"

rem Define default overridable variables
rem The update period in days (e.g., 3 means check if the last_checked file is older than 3 days)
set UPDATE_PERIOD=3
rem Logging level (default empty/silent; set to anything, e.g., 'DEBUG', to enable logging)
set LOG_LEVEL=

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

rem Helper function for logging
:LOG_ERROR
    if "%LOG_LEVEL%" NEQ "" (
        if 0 GEQ %LOG_LEVEL% 2>nul (
            echo ERROR: %~1
        )
    )
    goto :eof

:LOG_INFO
    if "%LOG_LEVEL%" NEQ "" (
        if 2 GEQ %LOG_LEVEL% 2>nul (
            echo [%APP_NAME% INFO] %~1
        )
    )
    goto :eof

rem --- Core Logic Functions ---

:UNPACK_AND_INSTALL
    set "RETURN_CODE=0"

    rem Unpack and clean up
    call :LOG_INFO "Unpacking application..."

    rem Remove existing installation directory if it exists before unpacking
    if exist "%APP_HOME%\temp_install" rmdir /s /q "%APP_HOME%\temp_install"

    rem Create a temporary directory for unpacking
    mkdir "%APP_HOME%\temp_install"

    rem Use the built-in 'tar' utility for ZIP/TAR.GZ extraction
    tar -xf "%ARCHIVE_FILE%" -C "%APP_HOME%\temp_install"
    if errorlevel 1 (
        call :LOG_ERROR "Failed to unpack archive %ARCHIVE_FILE%"
        rmdir /s /q "%APP_HOME%\temp_install"
        set "RETURN_CODE=1"
        goto :eof
    )

    rem Move all contents of temp_install to APP_HOME/app.new
    call :LOG_INFO "Moving contents to %HAP_DIR%"
    ren "%APP_HOME%\temp_install" "app.new"

    rem Replace the old app directory with the new one atomically
    if exist "%HAP_DIR%" (
        ren "%HAP_DIR%" "app.bak"
        ren "%HAP_DIR%.new" "app"
        rmdir /s /q "%HAP_DIR%.bak"
    ) else (
        ren "%HAP_DIR%.new" "app"
    )

    rem Clean up the temporary directory
    if exist "%APP_HOME%\temp_install" rmdir /s /q "%APP_HOME%\temp_install"

    call :LOG_INFO "Installation complete in %APP_HOME%"
    goto :eof

:DOWNLOAD_AND_INSTALL
    set "RETURN_CODE=0"
    set "UPDATE_NEEDED=false"

    rem Check file age: older than %UPDATE_PERIOD% days? (or doesn't exist)
    rem forfiles exits with ERRORLEVEL 0 if files matching the criteria are found.
    rem /D -N means files older than N days ago.
    forfiles /P "%CACHE_DIR%" /M last_checked /D -%UPDATE_PERIOD% /C "cmd /c echo Found > nul" 2>nul
    if errorlevel 1 (
        rem ERRORLEVEL 1 means no files older than %UPDATE_PERIOD% days were found (either file is new, or file doesn't exist)
        if not exist "%LAST_CHECKED_FILE%" (
            call :LOG_INFO "Checking for updates [file missing]..."
            set "UPDATE_NEEDED=true"
        ) else (
            rem Check for files older than %UPDATE_PERIOD% days
            set "IS_OLD=false"
            forfiles /P "%CACHE_DIR%" /M last_checked /D -%UPDATE_PERIOD% /C "cmd /c set IS_OLD=true" 2>nul
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
    if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" || (
        call :LOG_ERROR "Could not create cache directory %CACHE_DIR%"
        set "RETURN_CODE=1"
        goto :eof
    )

    rem -z "%ARCHIVE_FILE%" tells curl to only download if the remote file is newer than the local one.
    rem --remote-time (-r) ensures the new file uses the remote timestamp.
    rem Use -w "%{http_code}" to capture the status code
    set "HTTP_CODE=0"
    for /f %%i in ('curl -w "%%{http_code}" -fsSL --remote-time -z "!ARCHIVE_FILE!" "!DOWNLOAD_URL!" -o "!ARCHIVE_FILE!"') do (
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

:START

rem Load user-wide configuration (if exists)
call :LOAD_CONFIG "%APP_HOME%\bootstrap.cfg"

rem Load local configuration (if exists)
call :LOAD_CONFIG ".\%APP_DIR%\bootstrap.cfg"

rem -----------------------------

rem Define the remaining path variables using the (potentially overridden) NAME/UPDATE_PERIOD
set "CACHE_DIR=%APP_HOME%\_cache"
set "HAP_DIR=%APP_HOME%\app"
set "BIN_DIR=%HAP_DIR%\bin"
set "APP_EXE=%BIN_DIR%\%APP_NAME%.cmd"
set "ARCHIVE_FILE=%CACHE_DIR%\release.zip"
set "LAST_CHECKED_FILE=%CACHE_DIR%\last_checked"

rem --- Execution Flow ---

rem Installation/Update Check
call :LOG_INFO "Check for executable %APP_EXE%"
if not exist "%APP_EXE%" (
    call :LOG_INFO "Application not found. Starting download and install..."
    call :DOWNLOAD_AND_INSTALL
    if "!RETURN_CODE!" NEQ "0" (
        call :LOG_ERROR "Installation of application failed!"
        exit /b 1
    )
) else (
    call :LOG_INFO "Application found. Check if there is an update to install..."
    call :DOWNLOAD_AND_INSTALL
)

rem Execution Handover (The final requirement)
rem Get the full path of the current script's directory
set "SCRIPT_DIR=%~dp0"
rem Remove trailing backslash for comparison
set "SCRIPT_DIR_CLEAN=%SCRIPT_DIR%"
if "%SCRIPT_DIR_CLEAN:~-1%"=="\" set "SCRIPT_DIR_CLEAN=%SCRIPT_DIR_CLEAN:~0,-1%"

rem Check if the script's directory is NOT the bin directory
if /I NOT "%SCRIPT_DIR_CLEAN%" EQU "%BIN_DIR%" (
    call :LOG_INFO "Handing over execution to the installed application: %APP_EXE%"
    rem Use 'start' to run the application and allow the current script to exit immediately.
    rem %* passes all arguments to the new process.
    "%APP_EXE%" %*
    goto :eof
)

rem ##########################################
rem # BELOW THIS POINT YOU PUT YOUR OWN CODE #
rem ##########################################

rem This part is the "whatever might be there" section.
call :LOG_INFO "Running inside the application's environment [%BIN_DIR%]"

rem Your application's main logic or final execution step would go here if this script
rem *is* the final executable. Otherwise you can call out to other scripts or binaries as needed.

rem For simplicity, we just print a success message and exit.
echo ------------------------------------
echo This is application: %APP_NAME%
echo Arguments received : %*
echo ------------------------------------

endlocal
exit /b 0
