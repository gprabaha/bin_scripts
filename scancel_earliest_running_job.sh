# Get the list of running jobs for the user, sorted by submit time
jobs=$(squeue -u pg496 --state=RUNNING --sort=S --noheader -o "%A %S")

# Find the job with the earliest submit time
earliest_job=$(echo "$jobs" | awk 'NR==1 {print $1}')

if [ -n "$earliest_job" ]; then
    scancel $earliest_job
    echo "Cancelled job $earliest_job"
else
    echo "No running jobs found."
fi

