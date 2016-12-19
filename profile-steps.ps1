get-content $ENV:PACKER_LOG_PATH | select-string "shell script", "exited with code"
