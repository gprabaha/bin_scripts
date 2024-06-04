while true; do
    clear  # Clear the terminal window
    echo "Job Progress:"
    squeue -u pg496 # Display job queue status
    sleep 30  # Wait for 10 seconds before checking again
done

