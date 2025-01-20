#!/bin/bash

# Function to create a directory if it doesn't exist
ensure_directory() {
  local path="$1"
  if [ ! -d "$path" ]; then
    mkdir -p "$path"
  fi
}

# Function to download files and check completion
download_files() {
  local path="$1"
  local destination="$2"
  local depth="$3"
  local max_parallel_jobs="$4"
  local top_name="${path##*/}"
  local local_dest_path="$destination/$top_name"
  local tabs=""
  for ((i=0; i<depth; i++)); do tabs+="    "; done

  if [[ "$path" != *.* ]]; then
    ensure_directory "$local_dest_path"
    echo -e "${tabs}Folder: $top_name"

    local total_items=$(dbxcli ls -l "$path" 2>/dev/null | awk 'NR>1 {print $NF}' | wc -l | awk '{$1=$1};1')
    local current_item=1
    tabs+="    "

    dbxcli ls -l "$path" | awk 'NR>1 {print $NF}' | while read -r item; do
      local local_name="${item##*/}"
      echo -e "${tabs}Item $current_item of $total_items"
      local new_depth=$((depth+1))
      download_files "$item" "$local_dest_path" "$new_depth" "$max_parallel_jobs" &
      ((current_item++))

      # Limit number of parallel downloads
      while (( $(jobs -r | wc -l) >= max_parallel_jobs )); do
        sleep 1
      done
    done
    wait  # Wait for all background processes to complete
  else
    echo "$path" >> ongoing_downloads.log
    echo -e "${tabs}Downloading: $top_name"

    # Capture expected Dropbox file size
    dropbox_size=$(dbxcli ls -l "$path" 2>/dev/null | awk 'NR==2 {print $2}')

    dbxcli get "$path" "$local_dest_path" > /dev/null 2>&1 &
    pid=$!

    while kill -0 $pid 2>/dev/null; do sleep 1; done

    # Capture downloaded file size
    local_size=$(stat -c%s "$local_dest_path" 2>/dev/null)  # Linux
    # local_size=$(stat -f%z "$local_dest_path" 2>/dev/null)  # macOS

    if [[ "$dropbox_size" != "$local_size" ]]; then
      echo "Warning: File $top_name may be incomplete!" >> download_errors.log
    else
      echo "$path" >> completed_downloads.log
    fi
  fi
}

# Set default max_parallel_jobs to 16 if not provided
max_parallel_jobs="${3:-16}"

# Start downloading files and replicating directory structure
download_files "$1" "$2" 0 "$max_parallel_jobs"

# Ensure all downloads finish before exiting
wait
echo "Download completed. Checking for errors..."

# Identify unfinished downloads
comm -23 <(sort ongoing_downloads.log) <(sort completed_downloads.log) > unfinished_downloads.log
echo "Unfinished files saved to unfinished_downloads.log."
