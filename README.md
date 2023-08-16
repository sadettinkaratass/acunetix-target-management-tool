## Installation
To install the Acunetix Target Management Tool, follow the steps below:

1. Update and upgrade your host:
sudo apt update && sudo apt upgrade

2. Install jq:
sudo apt install jq

3. Clone the repository:
git clone https://github.com/muhammedkaratas/acunetix-target-management-tool.git

4. Run the target_manager.sh script:

## Usage
To use the tool, run `bash target_manager.sh` in the command line. You will be presented with a menu where you can select one of the following options:

- Add Group
- Start Group Scan
- Delete Group

Selecting an option will prompt you to enter the necessary information for that operation. Once the operation is completed, a notification will be sent through the Telegram bot.

## Requirements
- apikey: The correct key for the Acunetix API must be provided.
- ip: The IP address or domain of the server where Acunetix is installed must be provided.
- hosts.txt: A file containing the list of targets to be scanned is required and it should be in the same directory as target_manager.sh
- bot_token and chat_id: Optionally, if you want to receive notifications via a Telegram bot when a scan starts, you must create a Telegram bot and provide its bot_token and chat_id. If this feature will not be used, the relevant lines can be commented out or completely removed.

## Support
If you encounter any issues while using the Acunetix Target Management Tool, please create an issue in the GitHub repository.