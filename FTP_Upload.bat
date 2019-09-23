@echo off
setLocal EnableDelayedExpansion
cls
:: See help at the bottom.

:: Go stright to MAIN {skip defaults - it's first for easy conf only}
goto :MAIN


:: Change defaults here if needed
:DEFAULT_VAR_VALUES
set ftpServerAddr=ftp.elbitsystems.com
set ftpPort=21
set ftpUser=dp99662
set ftpDefaultStartLoc=/
set ftpGeneratedScriptPath=%~dp0ftpGeneratedScript.txt

EXIT /B



:: ---- Main Function ----
:MAIN
echo Started

:: Passing all received params to function below
call :CHECK_PARAMS_AND_ENV %*
call :INITIALIZE_ITEMS_TO_UPLOAD_FILE
call :POPULATE_ITEMS_TO_UPLOAD_LIST_FILE
call :PRINT_INFO_VARS

if defined silentFlag (
	call :CHECK_SILENT_PARAMS
) else (
	call :INTERACT_WITH_USER
	call :ASK_IF_SURE
)

call :GENERATE_FTP_SCRIPT
call :EXECUTE_GENERATED_FTP_SCRIPT
call :CLEAN_FTP_GENERATED_SCRIPT

echo Finished

goto :END


:CHECK_PARAMS_AND_ENV
echo Checking Params and Env...

call :READ_RECEIVED_PARAMS %*

if not defined ftpServerAddr set /a errorNum=10 && goto :Error
if not defined ftpUser set /a errorNum=11 && goto :Error
if not defined ftpDefaultStartLoc set /a errorNum=12 && goto :Error
if not defined ftpGeneratedScriptPath set /a errorNum=13 && goto :Error

where ftp
if %errorlevel% neq 0 set /a errorNum=20 && goto :Error

cls

EXIT /B


:READ_RECEIVED_PARAMS
:: Reset Vars
set varsToReset=ftpServerAddr ftpPort ftpUser ftpDefaultStartLoc ftpTargetsToUpload ftpTargetListToUpload silentFlag
for %%a in (!varsToReset!) do (set %%a=)

:: First assign default values from above:
call :DEFAULT_VAR_VALUES

:: Count & Read Variables:
set /a paramCount=0
for %%a in (%*) do (
	set /a paramCount+=1
	set params[!paramCount!]=%%~a
)

:: Assign values to variables according to flags:
set isFlag=1
for /L %%a in (1, 1, !paramCount!) do (	
	if !isFlag! equ 1 (
		set flag=!params[%%a]!
		set isFlag=0
		if /i "!flag!" == "-h" (call :PRINT_HELP_MESSAGE && pause && goto :END)
	) else (
		set value=!params[%%a]!
		set isFlag=1
		
		if /i "!flag!" == "-a" (set ftpServerAddr=!value!) 
		if /i "!flag!" == "-p" (set ftpPort=!value!) 
		if /i "!flag!" == "-u" (set ftpUser=!value!) 
		if /i "!flag!" == "-w" (set ftpPassword=!value!) 
		if /i "!flag!" == "-d" (set ftpDefaultStartLoc=!value!) 
		if /i "!flag!" == "-t" (set ftpTargetsToUpload=!value!) 
		if /i "!flag!" == "-l" (set ftpTargetsListToUpload=!value!) 
		if /i "!flag!" == "-s" (set silentFlag=1) 
	)
)

pause

EXIT /B



:CHECK_SILENT_PARAMS

if not defined ftpPassword set /a errorNum=30 && goto :Error
if not defined ftpTargetsToUpload if not defined ftpTargetsListToUpload set /a errorNum=31 && goto :Error

if defined ftpTargetsToUpload (
	for %%a in (!ftpTargetsToUpload!) do (
		if not exist "%%a" echo Missing: "%%a" && set /a errorNum=35 && goto :Error
	)
)

if defined ftpTargetsListToUpload if not exist "!ftpTargetsListToUpload!" set /a errorNum=37 && goto :Error

EXIT /B


:: Reading user input using a loop (with goto command)
:GET_USER_INPUT_ITEMS_TO_UPLOAD
echo.
echo Drag items one by one, to upload and press enter after each drag.
echo Press enter again when finished.
echo.
echo {Do NOT include items with brackets signs in them, for example: 'C:\Program Files (x86)\Babylon'}
echo.

goto :WHILE_READING_INPUT

:WHILE_READING_INPUT
:: Reset var:
set item=

set /p item=Drag item and hit enter: 

:: Check if user just pressed enter or dragged an item to upload:
if defined item (
	:: Add dragged item to the list:
	echo !item!>> "!itemsToUploadTempListFile!"
	cls
	echo.
	call :PRINT_ITEMS_TO_UPLOAD
	echo.
	echo Press enter to finish or drag another item and press enter
	echo.
	:: Continue reading
	goto :WHILE_READING_INPUT
)

goto :FINISHED_READING_ITEMS

:FINISHED_READING_ITEMS
:: If got here - then user pressed enter without dragging an item
cls
echo Finished reading.


EXIT /B


:GET_USER_INPUT_PASSWORD
echo.
echo Type password for FTP account: !ftpUser!
echo.
:: Reset var:
set ftpPassword=

set /p ftpPassword=!ftpUser! FTP Password: 

if not defined ftpPassword (
	echo Error - password cannot be empty
	goto :GET_USER_INPUT_PASSWORD
)

EXIT /B


:INITIALIZE_ITEMS_TO_UPLOAD_FILE

:: Defaults - no need to touch
set itemsToUploadTempListFile=%temp%\itemsToUpload.txt

:: Initialize items list file using 'break' command:
echo Initializing items to upload list file at:
echo "!itemsToUploadTempListFile!"
break>"!itemsToUploadTempListFile!"

EXIT /B


:POPULATE_ITEMS_TO_UPLOAD_LIST_FILE
:: Here no need to check if exists, since here we are already after check function :CHECK_SILENT_PARAMS 

:: - Multiple targets to upload
if defined ftpTargetsToUpload (
	for %%a in (!ftpTargetsToUpload!) do (
		echo %%a>> "!itemsToUploadTempListFile!"
	)
)

:: - File targets to upload
if defined ftpTargetsListToUpload (
	for /f %%a in (!ftpTargetsListToUpload!) do (
		echo %%a>> "!itemsToUploadTempListFile!"
	)
)

EXIT /B

:INTERACT_WITH_USER

if not defined ftpTargetsToUpload if not defined ftpTargetListToUpload call :GET_USER_INPUT_ITEMS_TO_UPLOAD
if not defined ftpPassword call :GET_USER_INPUT_PASSWORD

EXIT /B

:PRINT_INFO_VARS

echo ftpServerAddr=!ftpServerAddr!
echo ftpPort=!ftpPort!
echo ftpUser=!ftpUser!
echo ftpDefaultStartLoc=!ftpDefaultStartLoc!
if defined ftpTargetsListToUpload echo ftpTargetsListToUpload=!ftpTargetsListToUpload!
if defined ftpTargetsToUpload echo ftpTargetsToUpload=!ftpTargetsToUpload!

EXIT /B

:ASK_IF_SURE
cls
echo.
echo You are about to upload items:
call :PRINT_ITEMS_TO_UPLOAD
echo.
echo To your FTP account: !ftpUser!
echo to path: !ftpDefaultStartLoc!
echo.

CHOICE /C YN /M "Are you sure?"
:: 1=Y
:: 2=N

if %errorlevel% equ 2 echo Aborting.. && timeout /t 2 && exit 0


EXIT /B


:GENERATE_FTP_SCRIPT
cls
echo Generating FTP Script...

echo open !ftpServerAddr! !ftpPort!>"!ftpGeneratedScriptPath!"
echo !ftpUser!>>"!ftpGeneratedScriptPath!"
echo !ftpPassword!>>"!ftpGeneratedScriptPath!"

echo status>>"!ftpGeneratedScriptPath!"
echo cd "!ftpDefaultStartLoc!">>"!ftpGeneratedScriptPath!"


for /f %%a in (!itemsToUploadTempListFile!) do (
	:: Check if a folder:
	if exist "%%a\*" (
		call :GENERATE_DIR_CONTENTS_TO_UPLOAD "%%a" "!ftpGeneratedScriptPath!"
	) else (
		:: It's a file
		echo put "%%a">>"!ftpGeneratedScriptPath!"
	)
	
)

echo disconnect>>"!ftpGeneratedScriptPath!"
echo quit>>"!ftpGeneratedScriptPath!"

echo Finished generating ftp script

EXIT /B


:EXECUTE_GENERATED_FTP_SCRIPT
echo.
echo Executing FTP script: "!ftpGeneratedScriptPath!"
echo.

ftp -v -i -s:"!ftpGeneratedScriptPath!"

if %errorlevel% equ 0 (
	echo.
	echo Done executing ftp script - Successfuly
) else (
	echo.
	echo Done executing ftp script - Failure
	pause
)

EXIT /B


:PRINT_ITEMS_TO_UPLOAD

set /a itemsCount=0
for /f %%a in (!itemsToUploadTempListFile!) do (
	set /a itemsCount+=1
	echo !itemsCount!. %%a
)

EXIT /B




:GENERATE_DIR_CONTENTS_TO_UPLOAD
set dirToUpload=%~1
set ftpGeneratedScriptPath=%~2

:: Reset
set rootPrefix=
:: Extract Prefix
for /f "tokens=*" %%i in ("!dirToUpload!") do (
	set rootPrefix=%%~pi
)

:: Generate the commands:
for /f "tokens=*" %%i in ('dir /b /s "!dirToUpload!"') do (
	set fullItemLocalPath=%%i
	set pathOnly=%%~pi
	set noDriveFullPath=%%~pi%%~ni%%~xi
	
	
	:: Remove first char '\'
	set noDriveFullPath=!ftpDefaultStartLoc!!noDriveFullPath:%rootPrefix%=!
	set pathOnly=!ftpDefaultStartLoc!!pathOnly:%rootPrefix%=!
	
	:: Check if a folder:
	if exist "!fullItemLocalPath!\*" (
		echo mkdir "!noDriveFullPath!">>"!ftpGeneratedScriptPath!"
	) else (
		echo mkdir "!pathOnly!">>"!ftpGeneratedScriptPath!"
		echo cd "!pathOnly!">>"!ftpGeneratedScriptPath!"
		echo put "!fullItemLocalPath!">>"!ftpGeneratedScriptPath!"
	)
)


EXIT /B



:CLEAN_FTP_GENERATED_SCRIPT

if exist "!ftpGeneratedScriptPath!" (
	echo Removing Generated FTP script:
	echo  "!ftpGeneratedScriptPath!"
	del /q "!ftpGeneratedScriptPath!"
	if exist "!ftpGeneratedScriptPath!" set /a errorNum=45 && goto :Error
	echo Success removing generated FTP script
)

EXIT /B


:Error
echo.
echo Error
echo.

if !errorNum! equ 10 echo Var 'ftpServerAddr' is not defined. Set it at the start of this script, to the ip{or name} of your FTP server.
if !errorNum! equ 11 echo Var 'ftpUser' is not defined. Set it to at the start of this script, to the user that would be used to login to the FTP account.
if !errorNum! equ 12 echo Var 'ftpDefaultStartLoc' is not defined. Set it at the start of this script, to the starting location path in you FTP account.
if !errorNum! equ 13 echo Var 'ftpGeneratedScriptPath' is not defined. Set it at the start of this script, to a location where you want to generate the ftp script to.
if !errorNum! equ 20 echo FTP.exe is missing from this machine. Cannot run FTP commands.
if !errorNum! equ 30 echo Silent mode: missing password parameter For FTP user: !ftpUser!.
if !errorNum! equ 31 echo Silent mode: missing targets to upload {params: -t or -l}
if !errorNum! equ 35 echo Silent mode: one or more files from "!ftpTargetsToUpload!" are missing 
if !errorNum! equ 37 echo Silent mode: list file of itmes to upload="!ftpTargetsListToUpload!" is missing.
if !errorNum! equ 45 echo Failed to remove FTP script at: "!ftpGeneratedScriptPath!". You should remove it manually since it contains your password.

echo.
echo Aborting...
echo.

call :PRINT_HELP_MESSAGE

pause
exit 1


:PRINT_HELP_MESSAGE
echo.
echo This script uploads files\dirs to an FTP server automatically. It generates an FTP-commands script and executes it.
echo. 
echo  Usage:
echo 	FTP_Upload.bat [args]
echo. 
echo  Args:
echo   -a  :   FTP Server address. IP or name
echo   -p  :   Connection port 
echo   -u  :   User 
echo   -w  :   Password
echo   -d  :   Starting remote location/path (cd) at your FTP server. Set '/' to start at the root.
echo   -t  :   Single target file to upload
echo   -l  :   Text list of files to upload. One line for each file\dir
echo   -s  :   Silent mode. All necessary flags above must be provided, or assigned in the script under defaults function.
echo   -h  :   Show help message
echo.
echo  More:
echo    Normal - 1. Double click the script, then start dragging files and folders to upload one by one and press enter after each drag.
echo             2. press enter on empty input to finish.
echo             3. Enter your password.
echo             4. Press 'Y' to start upload.
echo.    
echo    Silent - See examples below for running this script in silent mode.
echo. 
echo. 
echo  Silent Mode Examples:
echo    Upload one file        -  FTP_Upload.bat -a 192.168.11.14 -p 21 -u myUser -w myPass -d / -t "C:\MyGitProjects\Tests\Test1.bat" -s
echo    Upload few files       -  FTP_Upload.bat -a myServ -p 21 -u myUser -w myPass -d / -t "C:\Test1.bat C:\Hello\World C:\Test2.bat D:\mydir" -s
echo    Upload list file  	   -  FTP_Upload.bat -a myServ -u myUser -w myPass -l "C:\FTP\UploadList.txt" -s
echo    Upload list and files  -  FTP_Upload.bat -a myServ -u myUser -w myPass -l "C:\FTP\UploadList.txt" -t "C:\Test1.bat C:\Hello\World C:\Test2.bat D:\mydir" -s
echo    Upload using defaults  -  FTP_Upload.bat -w myPass -t "C:\Test1.bat C:\Hello\World C:\Test2.bat D:\mydir" -s
echo. 
echo. 
echo  Known bugs :(
echo    * script will print errors trying to create a dir if it already exists - just ignore it, it's harmless..
echo    * If fail to login with user and password - the script will not stop, and will still try to upload
echo         listed files and dirs but with no success. After that it will print that it finished executing
echo         the FTP script successfully, eventhough it failed, But no harm is done anyway.
echo. 
echo. 
echo - Written by David Yair
echo. 
echo.

EXIT /B



:END

timeout /t 7
exit 0
