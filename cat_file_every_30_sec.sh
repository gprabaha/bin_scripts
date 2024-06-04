while true; do
    clear  # Clear the terminal window
    echo "Job Progress:"
    cat "$1" # Display the file
    sleep 30  # Wait for 10 seconds before checking again
done

