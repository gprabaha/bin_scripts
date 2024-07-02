#!/bin/bash

# Function to filter and display array jobs
display_array_jobs() {
  # Get the list of jobs for the user pg496
  squeue_output=$(squeue -u pg496)
  
  # Filter array jobs with _n in their job IDs
  array_jobs=$(echo "$squeue_output" | grep -E '_[0-9]+')

  # Print the filtered list of array jobs
  echo "Array jobs currently running:"
  echo "$array_jobs"

  # Count the number of array jobs
  array_jobs_count=$(echo "$array_jobs" | wc -l)
  echo "Number of array jobs running: $array_jobs_count"

  # Print the array jobs that have finished running
  finished_jobs=$(echo "$array_jobs" | awk '$5 ~ /CD|F|NF/ {print $1}')
  if [ -z "$finished_jobs" ]; then
    echo "No array jobs have finished running."
  else
    echo "Array jobs that have finished running:"
    echo "$finished_jobs"
  fi
}

# Main loop to refresh every 30 seconds
while true; do
  clear
  display_array_jobs
  sleep 30
done

