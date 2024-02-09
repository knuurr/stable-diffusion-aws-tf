#!/bin/bash

# Function to connect via SSH

# Common variables
SPOT_INSTANCE_REQUEST=$(terraform output spot_instance_request_id)
INSTANCE_ID=$(terraform output instance_id | tr -d '"')
# Default SSH key path
DEFAULT_SSH_KEY_PATH="${HOME}/.ssh/id_aws-sd"  # Default SSH key path

# Get the script file name
SCRIPT_NAME=$(basename "$0")

connect_ssh() {
    SSH_KEY_PATH="$1"
    PUBLIC_IP="$(aws ec2 describe-instances --instance-id $INSTANCE_ID | jq -r '.Reservations[].Instances[].PublicIpAddress')"

    if [ "$PUBLIC_IP" == "null" ]; then
        echo "[*] Error: Public IP not available. The instance may not be running or the IP is not assigned yet."
        exit 1
    fi
    echo "[*] Using SSH key: $SSH_KEY_PATH"
    echo "[*] Use http://localhost:7860 for automatic1111 or http://localhost:9090 for Invoke-AI"
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY_PATH -L7860:localhost:7860 -L9090:localhost:9090 admin@$PUBLIC_IP
    echo "[*] SSH connection closed."


}

# Function to stop the instance
stop_instance() {
    aws ec2 stop-instances --instance-ids $INSTANCE_ID
    echo "[*] Instance stopped."

}

# Function to start the instance
start_instance() {
    aws ec2 start-instances --instance-ids $INSTANCE_ID
    echo "[*] Instance started."
}


# Function to print help menu
print_help() {
    echo "Usage: ./$SCRIPT_NAME [command]"
    echo "Commands:"
    echo "  connect/ssh - Connect via SSH to the instance."
    echo "  stop        - Stop the instance."
    echo "  start       - Start the instance."
    echo "  help        - Print this help menu."
    echo "Options:"
    echo " -k, --key     Specify an alternative path for the SSH key (with 'connect/ssh' command)"


}

# Check for command-line argument
if [ $# -eq 0 ]; then
    print_help
    exit 1
fi


# Echo common variables
echo "[*] Spot Instance Request ID: $SPOT_INSTANCE_REQUEST"
echo "[*] Instance ID: $INSTANCE_ID"


# Parse command and arguments
case "$1" in
    "connect" | "ssh")  # Connect via SSH
        # Check for SSH key path argument
        if [ "$2" == "-k" ] || [ "$2" == "--key" ]; then
            SSH_KEY_PATH="$3"
        else
            SSH_KEY_PATH="$DEFAULT_SSH_KEY_PATH"
        fi
        connect_ssh $SSH_KEY_PATH
        ;;
    "stop")  # Stop the instance
        stop_instance
        ;;
    "start")
        start_instance
        # echo "[*] Waiting 15 seconds before attpeting to SSH..."
        # sleep 15
        # connect_ssh
        ;;
    "help")  # Print help menu
        print_help
        ;;
    *)  # Invalid command
        echo "[*] Error: Invalid command. Use './$SCRIPT_NAME help' for usage instructions."
        exit 1
        ;;
esac
