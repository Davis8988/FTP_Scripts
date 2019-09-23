# FTP_Scripts
This script uploads files\dirs to an FTP server automatically. It generates an FTP-commands script and executes it.
 
## Usage
	FTP_Upload.bat [args]
 
## Args
  -a  :   FTP Server address. IP or name
  -p  :   Connection port 
  -u  :   User 
  -w  :   Password
  -d  :   Starting remote location/path (cd) at your FTP server. Set '/' to start at the root.
  -t  :   Single target file to upload
  -l  :   Text list of files to upload. One line for each file\dir
  -s  :   Silent mode. All necessary flags above must be provided, or assigned in the script under defaults function.
  -h  :   Show help message

## More
   Normal - 1. Double click the script, then start dragging files and folders to upload one by one and press enter after each drag.
            2. press enter on empty input to finish.
            3. Enter your password.
            4. Press 'Y' to start upload.
    
   Silent - See examples below for running this script in silent mode.
 
 
## Silent Mode Examples
   Upload one file        -  FTP_Upload.bat -a 192.168.11.14 -p 21 -u myUser -w myPass -d / -t "C:\MyGitProjects\Tests\Test1.bat" -s
   Upload few files       -  FTP_Upload.bat -a myServ -p 21 -u myUser -w myPass -d / -t "C:\Test1.bat C:\Hello\World C:\Test2.bat D:\mydir" -s
   Upload list file  	   -  FTP_Upload.bat -a myServ -u myUser -w myPass -l "C:\FTP\UploadList.txt" -s
   Upload list and files  -  FTP_Upload.bat -a myServ -u myUser -w myPass -l "C:\FTP\UploadList.txt" -t "C:\Test1.bat C:\Hello\World C:\Test2.bat D:\mydir" -s
   Upload using defaults  -  FTP_Upload.bat -w myPass -t "C:\Test1.bat C:\Hello\World C:\Test2.bat D:\mydir" -s
 
 
# Known bugs
   * script will print errors trying to create a dir if it already exists - just ignore it, it's harmless..
   * If fail to login with user and password - the script will not stop, and will still try to upload
        listed files and dirs but with no success. After that it will print that it finished executing
        the FTP script successfully, eventhough it failed, But no harm is done anyway.
 
 
- Written by David Yair