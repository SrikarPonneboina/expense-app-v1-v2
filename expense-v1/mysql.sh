#!/bin/bash

LOGS_FOLDER="/var/log/expense"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1) 
#here script_name captures backend. .. $0 is the special variable which takes the script name and where we are seperating frontend.sh with (.).
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S) 
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME-$TIMESTAMP.log"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
BR="\e[1;31m"
BG="\e[1;32m"
RESET="\e[0m"
mkdir -p "$LOGS_FOLDER"

# example file created in this way backend-2026-11-16-23-07-00.log

user_id=$(id -u)

if [ $user_id -ne 0 ]; then
    echo -e "${BR}ERROR${RESET}: please run with sudo access" 
    exit 1
fi

echo "configure mysql server"
echo "-------------------------"

validate(){
    exitstatus=$1
    description=$2
    if [ $exit_status -ne 0 ]; then
        echo -e "${description}..${R}FAILED${RESET}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "${description}..${BG}SUCCESS${RESET}" | tee -a "$LOG_FILE"
    fi
}

echo "Script started at: $(date)" | tee -a "$LOG_FILE"
echo "================================="

dnf install mysql-server -y &>> "$LOG_FILE"
validate "$?" "installing mysql server"

systemctl enable mysqld &>> "$LOG_FILE"
validate "$?" "enable mysql service"

systemctl start mysqld &>> "$LOG_FILE"
validate "$?" "start mysql service"

mysql_secure_installation --set-root-pass ExpenseApp@1
validate "$?" "setting up mysql root password for database"

echo "================================="
echo "Script completed at: $(date)" | tee -a "$LOG_FILE"



