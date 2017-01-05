get-content $ENV:PACKER_LOG_PATH | select-string "shell script", "Communicator ended with" #"exited with code", 
