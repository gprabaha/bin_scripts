#!/bin/bash

# Check if a commit message was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <commit message>"
  exit 1
fi

# Get the commit message from the input argument
commit_message="$1"

# Run the git commands
git add -A
git commit -m "$commit_message"
git push origin main

# Check if the commands were successful
if [ $? -eq 0 ]; then
  echo "Changes committed and pushed to main successfully."
else
  echo "An error occurred. Please check the output above for details."
fi

