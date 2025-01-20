#!/bin/bash

# Function to create a directory if it doesn't exist
ensure_directory() {
  local path="$1"
  if [ ! -d "$path" ]; then
    mkdir -p "$path"
  fi
}

# Function to download a single file and check completion
download_file() {
  local path="$1"
  local destination="$2"

  echo "Downloading: $path"
  dropbox_size=$(dbxcli ls -l "$path" 2>/dev/null | awk 'NR==2 {print $2}')

  dbxcli get "$path" "$destination" > /dev/null 2>&1
  local_size=$(stat -c%s "$destination" 2>/dev/null)  # Linux
  # local_size=$(stat -f%z "$destination" 2>/dev/null)  # macOS

  if [[ "$dropbox_size" != "$local_size" ]]; then
    echo "Warning: File $path may be incomplete!" >> download_errors.log
  else
    echo "$path" >> completed_downloads.log  # Mark as completed
  fi
}

# Function to download files and directories in parallel
download_files() {
  local path="$1"
  local destination="$2"
  local max_parallel_jobs="$3"
  local job_pids=()  # Array to track background job PIDs

  ensure_directory "$destination"

  # Process directories and files
  while read -r item; do
    local local_dest_path="$destination/${item##*/}"

    if [[ "$item" != *.* ]]; then
      ensure_directory "$local_dest_path"
      download_files "$item" "$local_dest_path" "$max_parallel_jobs"  # Recursive call for directories
    else
      echo "$item" >> ongoing_downloads.log
      download_file "$item" "$local_dest_path" &  # Run in background
      job_pids+=("$!")  # Store job PID

      # Control parallel downloads
      while (( $(jobs -r | wc -l) >= max_parallel_jobs )); do
        sleep 1
      done
    fi
  done < <(dbxcli ls -l "$path" 2>/dev/null | awk 'NR>1 {print $NF}')  # Prevent subshell issue

  # Wait for all background jobs to complete
  if [[ ${#job_pids[@]} -gt 0 ]]; then
    wait "${job_pids[@]}"
  fi
}

# Ensure logs exist
touch ongoing_downloads.log completed_downloads.log download_errors.log

# Max parallel downloads (default: 16)
max_parallel_jobs="${3:-16}"

# Ensure the top-level directory is created
TOP_FOLDER_NAME="${1##*/}"   # Extracts "Lynch" from "BRAINS_Recording_Backup/Lynch"
FULL_DEST_PATH="$2/$TOP_FOLDER_NAME"
ensure_directory "$FULL_DEST_PATH"

# Start downloading files and directories inside the top-level folder
download_files "$1" "$FULL_DEST_PATH" "$max_parallel_jobs"

# Ensure all downloads finish before script exits
echo "Download completed. Checking for errors..."

# Identify unfinished downloads
comm -23 <(sort ongoing_downloads.log) <(sort completed_downloads.log) > unfinished_downloads.log
echo "Unfinished files saved to unfinished_downloads.log."

