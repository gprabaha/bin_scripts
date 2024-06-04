# Get the list of all jobs for the user, excluding the header row
jobs=$(squeue -u pg496 --noheader)

# Iterate through each job line
while read -r line; do
    # Extract the job ID and job name
    job_id=$(echo "$line" | awk '{print $1}')
    job_name=$(echo "$line" | awk '{print $3}')

    # Check if the job name does not contain "ood"
    if [[ ! $job_name =~ ood ]]; then
        # Cancel the job
        scancel $job_id
        echo "Cancelled job $job_id ($job_name)"
    fi
done <<< "$jobs"

