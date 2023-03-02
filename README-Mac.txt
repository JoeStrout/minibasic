WELCOME
-------
MiniBASIC runs within Mini Micro.  If you have downloaded MiniBASIC 
to run on your Mac, you should now have a folder with the following
files:

	MiniMicro (application)
	user.minidisk (folder)
	README-Mac.txt (this file)

To run MiniBASIC, you will just run Mini Micro.  You should see a
virtual computer appear with a MiniBASIC prompt.



IF MINI MICRO IS "DAMAGED" AND REFUSES TO RUN
---------------------------------------------
This is almost certainly because Finder has quarantined the file.
To fix this, you will need to open Terminal, and use a command like:

	xattr -d com.apple.quarantine /path/to/MiniMicro.app 

The easiest way to get the correct path is to type just

	xattr -d com.apple.quarantine 

...including a space after "quarantine", then drag the Mini Micro app
to your Terminal window, which will insert the correct path.  Press
Return to execute the command, and this should remove the quarantine
flag on the file, allowing Mini Micro to run.


NEED HELP?
----------
If you have any problems, contact us using the links at the bottom of

	https://miniscript.org

Discord is an especially good and fast way to get help, but we will
respond to email or forum posts as well.

Have fun!
