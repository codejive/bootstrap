@echo off
setlocal

rem --- Configuration ---
set NAME=APP
set "APP_HOME=%HOME_DIR%\.%NAME%"
set RELEASE_URL=https://example.com/releases/foo-latest.zip
rem ---------------------

rem --- Environment Setup ---
set "HOME_DIR=%USERPROFILE%"
set "CACHE_DIR=%APP_HOME%\cache"
set "BIN_DIR=%APP_HOME%\bin"
set "APP_EXE=%BIN_DIR%\%NAME%.cmd"
set "ARCHIVE_FILE=%CACHE_DIR%\release.zip"
set "LAST_CHECKED_FILE=%CACHE_DIR%\last_checked"

rem Helper function for logging
:LOG
    echo [Installer] %~1
    goto :eof

rem --- Core Logic Functions ---

:PERFORM_FULL_INSTALL
    call :LOG "Application not found or update forced. Starting download and install..."
    
    rem 1. Setup directories
    if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" || (
        call :LOG "Error: Could not create cache directory %CACHE_DIR%"
        exit /b 1
    )

    rem 2. Download the release archive
    call :LOG "Downloading %RELEASE_URL%..."
    rem The --remote-time (-r) option ensures the local file date matches the remote server's date.
    rem curl -o saves the output to the specified file
    curl -fsSL --remote-time "%RELEASE_URL%" -o "%ARCHIVE_FILE%"
    if errorlevel 1 (
        call :LOG "Error: Download failed for %RELEASE_URL%."
        exit /b 1
    )

    rem 3. Unpack and clean up
    call :LOG "Unpacking application..."
    
    rem Remove existing installation directory if it exists before unpacking
    if exist "%APP_HOME%\temp_install" rmdir /s /q "%APP_HOME%\temp_install"
    
    rem Create a temporary directory for unpacking
    mkdir "%APP_HOME%\temp_install"

    rem Use the built-in 'tar' utility for ZIP extraction
    tar -xf "%ARCHIVE_FILE%" -C "%APP_HOME%\temp_install"
    if errorlevel 1 (
        call :LOG "Error: Failed to unpack archive %ARCHIVE_FILE%. Check if it's a valid ZIP."
        rmdir /s /q "%APP_HOME%\temp_install"
        exit /b 1
    )

    rem Move contents from the temporary unpack location to the application home
    rem This requires navigating the directory structure, which is complex in Batch.
    rem We will assume the archive root needs to be moved into APP_HOME.
    
    rem Move everything from temp_install (including the content of any single root folder)
    rem Note: This assumes the ZIP contains a single root folder or direct files.
    
    rem Use XCOPY to move files/directories
    call :LOG "Moving contents to %APP_HOME%"
    
    rem Copy everything from temp_install to APP_HOME (excluding temp_install itself)
    rem /E: Copy subdirectories, including empty ones. /Y: Suppress prompting to overwrite.
    xcopy "%APP_HOME%\temp_install\*" "%APP_HOME%\" /E /Y /I >nul 2>nul
    
    rem Clean up the temporary directory
    rmdir /s /q "%APP_HOME%\temp_install"

    rem 4. Create/update the last_checked file
    type nul > "%LAST_CHECKED_FILE%"
    call :LOG "Installation complete in %APP_HOME%."
    goto :eof

:HANDLE_UPDATE_CHECK
    set "UPDATE_NEEDED=false"
    
    rem Check file age: older than 3 days? (or doesn't exist)
    rem forfiles exits with ERRORLEVEL 0 if files matching the criteria are found.
    rem /D -3 means files older than 3 days ago.
    forfiles /P "%CACHE_DIR%" /M last_checked /D -3 /C "cmd /c echo Found > nul" 2>nul
    if errorlevel 1 (
        rem ERRORLEVEL 1 means no files older than 3 days were found (either file is new, or file doesn't exist)
        rem We need the inverse logic: We want to update if it DOESN'T exist OR if it IS older.
        if not exist "%LAST_CHECKED_FILE%" (
            set "UPDATE_NEEDED=true"
        ) else (
            rem Re-check: forfiles /D -N checks for files older than N days.
            rem If no file is found, the file is either missing or newer than N days.
            rem The initial check is flawed for the "newer than" case.
            
            rem Simpler, more reliable check: find if any file named last_checked *exists*.
            rem If it exists, use forfiles to check if it's OLDER than 3 days.
            set "IS_OLD=true"
            forfiles /P "%CACHE_DIR%" /M last_checked /D -3 /C "cmd /c set IS_OLD=false" 2>nul
            if "%IS_OLD%"=="true" (
                call :LOG "Checking for updates (last check older than 3 days or file missing)..."
                set "UPDATE_NEEDED=true"
            ) else (
                call :LOG "Skipping update check (last check within 3 days)."
                goto :eof
            )
        )
    ) else (
        rem The file exists and IS older than 3 days, so ERRORLEVEL 0 was returned.
        call :LOG "Checking for updates (last check older than 3 days)..."
        set "UPDATE_NEEDED=true"
    )
    
    if "%UPDATE_NEEDED%"=="true" (
        rem 2. Conditional Download
        rem Record the size of the current archive
        set "OLD_SIZE=0"
        if exist "%ARCHIVE_FILE%" for %%F in ("%ARCHIVE_FILE%") do set OLD_SIZE=%%~zF

        call :LOG "Attempting conditional download..."
        rem -z "%ARCHIVE_FILE%" tells curl to only download if the remote file is newer than the local one.
        rem --remote-time (-r) ensures the new file uses the remote timestamp.
        curl -fsSL --remote-time -z "%ARCHIVE_FILE%" "%RELEASE_URL%" -o "%ARCHIVE_FILE%"
        
        set "CURL_EXIT_CODE=%ERRORLEVEL%"
        
        if "%CURL_EXIT_CODE%"=="0" (
            rem Check if the file size changed (indicating a new file was downloaded)
            set "NEW_SIZE=0"
            if exist "%ARCHIVE_FILE%" for %%F in ("%ARCHIVE_FILE%") do set NEW_SIZE=%%~zF
            
            if not "%OLD_SIZE%"=="%NEW_SIZE%" (
                call :LOG "New release downloaded (size changed: Old=%OLD_SIZE%, New=%NEW_SIZE%). Unpacking update."
                rem 4. Unpack the new release
                call :PERFORM_FULL_INSTALL
            ) else (
                call :LOG "No new release available or conditional download skipped."
            )
        ) else (
            rem curl exit code non-zero (might be failure or 304 Not Modified if verbose)
            call :LOG "Conditional download failed or returned Not Modified. Skipping unpack."
        )

        rem 5. Update last_checked timestamp regardless of success/failure of the update attempt
        type nul > "%LAST_CHECKED_FILE%"
        call :LOG "Update check complete. Timestamp updated."
    )
    goto :eof

rem --- Execution Flow ---

rem 1. Installation/Update Check
if not exist "%APP_EXE%" (
    call :PERFORM_FULL_INSTALL
) else (
    rem Ensure cache directory exists for the last_checked file
    if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"
    call :HANDLE_UPDATE_CHECK
)

rem 2. Execution Handover (The final requirement)
rem Get the full path of the current script's directory
set "SCRIPT_DIR=%~dp0"
rem Remove trailing backslash for comparison
set "SCRIPT_DIR_CLEAN=%SCRIPT_DIR%"
if "%SCRIPT_DIR_CLEAN:~-1%"=="\" set "SCRIPT_DIR_CLEAN=%SCRIPT_DIR_CLEAN:~0,-1%"

rem Check if the script's directory is NOT the bin directory
if /I NOT "%SCRIPT_DIR_CLEAN%" EQU "%BIN_DIR%" (
    call :LOG "Handing over execution to the installed application: %APP_EXE%"
    rem Use 'start' to run the application and allow the current script to exit immediately.
    rem %* passes all arguments to the new process.
    start "" "%APP_EXE%" %*
    goto :eof
)

rem If we are running from %BIN_DIR%, the script continues below this line.
call :LOG "Running inside the application's environment (%BIN_DIR%)."
rem This is the "whatever might be there" section.
echo --- Application %NAME% is running ---
echo Arguments received: %*
echo ------------------------------------

endlocal
exit /b 0