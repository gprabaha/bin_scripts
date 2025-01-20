#!/bin/bash

#SBATCH --job-name=rsync_parallel
#SBATCH --cpus-per-task=48
#SBATCH --mem-per-cpu=1G
#SBATCH --time=4:00:00
#SBATCH --partition=psych_day
#SBATCH --output=rsync_parallel_%j.out  # Optional: outputs to a file named rsync_parallel_JOBID.out

# Load the parallel module
module load parallel

# Define the source and destination directories
SRC_DIR="/gpfs/milgram/project/pi/chang/pg496/data_dir/otnal/"
DEST_DIR="/gpfs/milgram/globus/pg496/"

# Define the path where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Generate the list of files with their relative paths
find $SRC_DIR -type f > "$SCRIPT_DIR/paths_of_files_to_transfer.txt"

# Run the rsync command in parallel, maintaining the directory structure within the 'otnal' directory
cat "$SCRIPT_DIR/paths_of_files_to_transfer.txt" | parallel --bar -j 48 --shuf rsync -avR --ignore-existing {} $DEST_DIR
