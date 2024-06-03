#!/bin/bash

# Dropbox path
DROPBOX_PATH="/prabaha_changlab/data_backup"
LOCAL_PATH="/gpfs/milgram/project/chang/pg496/data_dir"

# Function to create a directory in Dropbox if it doesn't exist
ensure_directory() {
  local path="$1"
  if ! dbxcli ls "$path" &>/dev/null; then
    dbxcli mkdir "$path"
  fi
}

# Function to upload files and replicate directory structure
upload_files() {
  local path="$1"
  local destination="$2"
  local depth="$3"
  local max_parallel_jobs="$4"
  local tabs=""
  for ((i=0; i<depth; i++)); do
    tabs+="    "
  done

  # Iterate over items in the directory
  for item in "$path"/*; do
    local local_name="${item##*/}"
    local dropbox_dest_path="$destination/$local_name"
    local new_depth=$((depth+1))

    if [ -d "$item" ]; then
      ensure_directory "$dropbox_dest_path"
      echo -e "${tabs}Folder: $local_name"
      upload_files "$item" "$dropbox_dest_path" "$new_depth" "$max_parallel_jobs"
    else
      # Get the modification time of the local file
      local local_mod_time=$(stat -c %Y "$item")
      local dropbox_mod_time=0

      # Get metadata of the Dropbox file if it exists
      dropbox_meta=$(dbxcli metadata "$dropbox_dest_path" 2>/dev/null)
      if [ $? -eq 0 ]; then
        dropbox_mod_time=$(echo "$dropbox_meta" | grep client_modified | awk -F'"' '{print $4}' | xargs -I{} date -d "{}" +%s)
      fi

      if [ "$local_mod_time" -gt "$dropbox_mod_time" ]; then
        echo -e "${tabs}Uploading: $local_name"
        dbxcli put "$item" "$dropbox_dest_path" > /dev/null 2>&1 &

        # Limit the number of parallel jobs
        while (( $(jobs -r | wc -l) >= max_parallel_jobs )); do
          sleep 1
        done
      else
        echo -e "${tabs}Skipped: $local_name"
      fi
    fi
  done
}

# Set default max_parallel_jobs to 8 if not provided
max_parallel_jobs="${3:-8}"

# Upload files and replicate directory structure
upload_files "$LOCAL_PATH" "$DROPBOX_PATH" 0 "$max_parallel_jobs"

# Wait for all background processes to finish
wait

echo "Upload completed."

