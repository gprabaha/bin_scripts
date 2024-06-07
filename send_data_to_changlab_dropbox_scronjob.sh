#!/bin/bash

# Define source and destination directories
LOCAL_PATH="/gpfs/milgram/project/chang/pg496/data_dir"
DROPBOX_PATH="/prabaha_changlab/data_backup"

# Maximum number of parallel jobs
MAX_JOBS=16

# Log directory and file
LOG_DIR="$HOME/logs"
LOG_FILE="$LOG_DIR/dropbox_transfer_log_$(date '+%Y%m%d_%H%M%S').txt"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Temporary files to store directory trees
SOURCE_TREE=$(mktemp)
DEST_TREE=$(mktemp)
FILES_TO_COPY=$(mktemp)

# Generate source directory tree
tree -if --noreport "$LOCAL_PATH" > "$SOURCE_TREE"

# Generate destination directory tree
dbxcli ls -R "$DROPBOX_PATH" | awk '{print $3}' > "$DEST_TREE"

# Function to get modification time for source file
get_source_mtime() {
    stat -c %Y "$1"
}

# Function to get modification time for destination file
get_dest_mtime() {
    dbxcli revs "$1" | awk 'NR==2 {print $1}' | xargs -I {} date -d {} +%s
}

# Function to run a job and limit the number of parallel jobs
run_job() {
    while [[ $(jobs -r -p | wc -l) -ge $MAX_JOBS ]]; do
        sleep 1
    done
    "$@" &
}

# Log function
log() {
    local status="$1"
    local file="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $status: $file" >> "$LOG_FILE"
}

# Compare source and destination trees
while IFS= read -r src_file; do
    # Remove source directory prefix
    rel_path="${src_file#$LOCAL_PATH/}"
    dest_file="$DROPBOX_PATH/$rel_path"

    if grep -q "$rel_path" "$DEST_TREE"; then
        src_mtime=$(get_source_mtime "$src_file")
        dest_mtime=$(get_dest_mtime "$dest_file")
        if [[ "$src_mtime" -gt "$dest_mtime" ]]; then
            echo "$src_file $dest_file" >> "$FILES_TO_COPY"
        else
            log "SKIPPED" "$src_file"
        fi
    else
        echo "$src_file $dest_file" >> "$FILES_TO_COPY"
    fi
done < "$SOURCE_TREE"

# Create directories and transfer files
cat "$FILES_TO_COPY" | while read src_file dest_file; do
    dest_dir=$(dirname "$dest_file")
    dbxcli mkdir -p "$dest_dir"
    if dbxcli put "$src_file" "$dest_file"; then
        log "TRANSFERRED" "$src_file"
    else
        log "FAILED" "$src_file"
    fi &
    run_job wait
done

# Wait for all background jobs to finish
wait

# Clean up
rm "$SOURCE_TREE" "$DEST_TREE" "$FILES_TO_COPY"

echo "Files have been synchronized successfully. See $LOG_FILE for details."

