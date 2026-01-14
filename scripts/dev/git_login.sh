#!/bin/bash

# Change username and password
USERNAME=""
PASSWORD="" 

# Change repository directory and repository name
REPO_PATH=""
REPO_NAME=""

eval cd $REPO_PATH 
git push https://$USERNAME:$PASSWORD@github.com/$USERNAME/$REPO_NAME

# Change timeout (seconds)
TIMEOUT=3600
git config credential.helper 'cache --timeout '$TIMEOUT''

# Exit Daemon
# git credential-cache exit
