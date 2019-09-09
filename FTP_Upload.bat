@echo off
setLocal EnableDelayedExpansion
cls

:: 
:: This script uploads files to ftp automatically. It generates an FTP-commands script and executes it.
:: 
::  Configuration:
::    - ftpServerAddr : FTP server address - if your using Elbit's then leave it: ftp.elbitsystems.com
::    - ftpUser : your FTP-User to var: 'ftpUser' before launching this script.
::    - ftpDefaultStartLoc : Starting remote location (cd) at your FTP path. Set '/' to start at the root.
::    - ftpGeneratedScriptPath : Location of the generated FTP script. 
::
::    * No need to set the silent vars - they are assigned by command line parameters.	
::
::
::  Usage:
::    Normal - 1. Double click the script, then start dragging files and folders to upload one by one and press enter after each drag.
::             2. press enter on empty input to finish.
::             3. Enter your password.
::             4. Press 'Y' to start upload.
::    
::    Silent - 1. Prepare text file containing all your files and dirs to upload (one file\dir for each line)
::             2. Open cmd and launch: FTP_Upload.bat -silent "MyPass101" "C:\myFiles\FilesToUpload.txt"
:: 
:: 
:: Known bugs:
::    * script will print errors trying to create a dir if it already exists
::    * If fail to login with user and password - the script will not stop, and will still try to upload
::         listed files and dirs but with no success. After that it will print that it finished executing
::         the FTP script successfully, eventhough it failed. Anyway - no harm is done.
:: 
:: 
:: Written by David Yair
:: 
::

:: Defaults
set ftpServerAddr=ftp.elbitsystems.com
set ftpUser=dp99662
set ftpDefaultStartLoc=/
set ftpGeneratedScriptPath=%~dp0ftpGeneratedScript.txt


goto :START



:START
echo Started

:: Passing all received params to function below
call :CHECK_PARAMS_AND_ENV %*

if defined silentFlag (
	call :CHECK_SILENT_PARAMS
	
) else (
	call :GET_USER_INPUT_ITEMS_TO_UPLOAD
	call :GET_USER_INPUT_PASSWORD
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

if not defined ftpServerAddr set /a errorNum=1 && goto :Error
if not defined ftpUser set /a errorNum=2 && goto :Error
if not defined ftpDefaultStartLoc set /a errorNum=3 && goto :Error
if not defined ftpGeneratedScriptPath set /a errorNum=4 && goto :Error

where ftp
if %errorlevel% neq 0 set /a errorNum=5 && goto :Error

cls

EXIT /B


:READ_RECEIVED_PARAMS
:: Reset vars:
for %%a in (ftpServerAddr ftpUser ftpPassword ftpDefaultStartLoc ftpTargetToUpload ftpTargetsListToUpload) do (set %%a=)

:: Count & Read Variables:
set /a paramCount=0
for %%a in (%*) do (
	set /a paramCount+=1
	set params[!paramCount!]=%%a
)

:: Assign values to variables according to flags:
set isFlag=1
for /L %%a in (1, 1, !paramCount!) do (	
	if !isFlag! equ 1 (
		set flag=!params[%%a]!
		set isFlag=0
	) else (
		set value=!params[%%a]!
		set isFlag=1
		
		if /i "!flag!" == "-a" (set ftpServerAddr=!value!) 
		if /i "!flag!" == "-u" (set ftpUser=!value!) 
		if /i "!flag!" == "-p" (set ftpPassword=!value!) 
		if /i "!flag!" == "-d" (set ftpDefaultStartLoc=!value!) 
		if /i "!flag!" == "-t" (set ftpTargetToUpload=!value!) 
		if /i "!flag!" == "-l" (set ftpTargetsListToUpload=!value!) 
		if /i "!flag!" == "-s" (set silentFlag=1) 
		if /i "!flag!" == "-h" (goto :HELP)
	)
)

EXIT /B



:CHECK_SILENT_PARAMS

if not defined ftpPassword set /a errorNum=6 && goto :Error
if not defined ftpTargetToUpload if not defined ftpTargetsListToUpload set /a errorNum=7 && goto :Error
if not exist "%ftpTargetToUpload%" if not exist "%ftpTargetsListToUpload%" set /a errorNum=8 && goto :Error

EXIT /B


:GET_USER_INPUT_ITEMS_TO_UPLOAD
:: Defaults - no need to touch
set itemsToUploadTempListFile=%temp%\itemsToUpload.txt

echo.
echo Drag items one by one, to upload and press enter after each drag.
echo Press enter again when finished.
echo.
echo {Do NOT include items with brackets signs in them, for example: 'C:\Program Files (x86)\Babylon'}
echo.


:: Initialize items list file using 'break' command:
echo Initializing items to upload list file at:
echo "%itemsToUploadTempListFile%"
break>"%itemsToUploadTempListFile%"


goto :WHILE_READING

:WHILE_READING
:: Reset var:
set item=

set /p item=Drag item and hit enter: 

:: Check if user just pressed enter or dragged an item to upload:
if defined item (
	:: Add dragged item to the list:
	echo !item!>> "%itemsToUploadTempListFile%"
	cls
	echo.
	call :PRINT_ITEMS_TO_UPLOAD
	echo.
	echo Press enter to finish or drag another item and press enter
	echo.
	:: Continue reading
	goto :WHILE_READING
)

goto :FINISHED_READING_ITEMS

:FINISHED_READING_ITEMS
:: If got here - then user pressed enter without dragging an item
cls
echo Finished reading.


EXIT /B


:GET_USER_INPUT_PASSWORD
echo.
echo Type password for FTP account: %ftpUser%
echo.
:: Reset var:
set ftpPassword=

set /p ftpPassword=%ftpUser% FTP Password: 

if not defined ftpPassword (
	echo Error - password cannot be empty
	goto :GET_USER_INPUT_PASSWORD
)

EXIT /B


:ASK_IF_SURE
cls
echo.
echo You are about to upload items:
call :PRINT_ITEMS_TO_UPLOAD
echo.
echo To you FTP account: %ftpUser%
echo to path: %ftpDefaultStartLoc%
echo.

CHOICE /C YN /M "Are you sure?"
:: 1=Y
:: 2=N

if %errorlevel% equ 2 echo Aborting.. && timeout /t 2 && exit 0


EXIT /B


:GENERATE_FTP_SCRIPT
cls
echo Generating FTP Script...

echo open %ftpServerAddr%>"%ftpGeneratedScriptPath%"
echo %ftpUser%>>"%ftpGeneratedScriptPath%"
echo %ftpPassword%>>"%ftpGeneratedScriptPath%"

echo status>>"%ftpGeneratedScriptPath%"
echo cd "%ftpDefaultStartLoc%">>"%ftpGeneratedScriptPath%"


for /f %%a in (%itemsToUploadTempListFile%) do (
	:: Check if a folder:
	if exist "%%a\*" (
		call :GENERATE_DIR_CONTENTS_TO_UPLOAD "%%a" "%ftpGeneratedScriptPath%"
	) else (
		:: It's a file
		echo put "%%a">>"%ftpGeneratedScriptPath%"
	)
	
)

echo disconnect>>"%ftpGeneratedScriptPath%"
echo quit>>"%ftpGeneratedScriptPath%"

echo Finished generating ftp script

EXIT /B


:EXECUTE_GENERATED_FTP_SCRIPT
echo.
echo Executing FTP script: "%ftpGeneratedScriptPath%"
echo.

ftp -v -i -s:"%ftpGeneratedScriptPath%"

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
for /f %%a in (%itemsToUploadTempListFile%) do (
	set /a itemsCount+=1
	echo !itemsCount!. %%a
)

EXIT /B




:GENERATE_DIR_CONTENTS_TO_UPLOAD
set dirToUpload=%~1
set ftpGeneratedScriptPath=%~2

:: Extract Prefix
for /f "tokens=*" %%i in ("%dirToUpload%") do (
	set rootPrefix=%%~pi
)

:: Generate the commands:
for /f "tokens=*" %%i in ('dir /b /s "%dirToUpload%"') do (
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

if exist "%ftpGeneratedScriptPath%" (
	echo Removing Generated FTP script:
	echo  "!ftpGeneratedScriptPath!"
	del /q "!ftpGeneratedScriptPath!"
	if exist "!ftpGeneratedScriptPath!" set /a errorNum=9 && goto :Error
	echo Removed Generated FTP script successfully
)

EXIT /B


:Error
echo.
echo Error
echo.

if !errorNum! equ 1 echo Var 'ftpServerAddr' is not defined. Set it at the start of this script, to the ip{or name} of your FTP server.
if !errorNum! equ 2 echo Var 'ftpUser' is not defined. Set it to at the start of this script, to the user that would be used to login to the FTP account.
if !errorNum! equ 3 echo Var 'ftpDefaultStartLoc' is not defined. Set it at the start of this script, to the starting location path in you FTP account.
if !errorNum! equ 4 echo Var 'ftpGeneratedScriptPath' is not defined. Set it at the start of this script, to a location where you want to generate the ftp script to.
if !errorNum! equ 5 echo FTP.exe is missing from this machine. Cannot run FTP commands.
if !errorNum! equ 6 echo Silent mode missing second parameter: password. For FTP user: %ftpUser%.
if !errorNum! equ 7 echo Silent mode missing third parameter: items-to-upload file path.
if !errorNum! equ 8 echo Items to upload list file doesn't exist at: itemsToUploadTempListFile="%itemsToUploadTempListFile%".
if !errorNum! equ 9 echo Failed to remove FTP script at: "!ftpGeneratedScriptPath!". You should remove it manually since it contains your password.
if !errorNum! equ 10 echo Wrong silent activation. Example: FTP_Upload.bat -silent "MyPass101" "C:\myFiles\FilesToUpload.txt"

echo.
echo Aborting...
echo.
pause
exit 1


:HELP



goto :END


:END

timeout /t 7
exit 0
