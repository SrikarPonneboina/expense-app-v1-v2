#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
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

echo "configure backend nginx"
echo "----------------------------"
timestamp(){
    date +"%d-%b-%Y-%I-%M-%S-%p"
}
validate(){
    exitstatus=$1
    description=$2
    if [ "$exitstatus" -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${description}..${R}FAILED${RESET}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${description}..${BG}SUCCESS${RESET}" | tee -a "$LOG_FILE"
    fi
}

echo "Script started at: $(date)" | tee -a "$LOG_FILE"
echo "================================="


dnf module disable nodejs -y &>> "$LOG_FILE"
validate "$?" "disable nodejs default version"

dnf module enable nodejs:24 -y &>> "$LOG_FILE"
validate "$?" "enable nodejs version"

dnf install nodejs -y &>> "$LOG_FILE"
validate "$?" "install nodejs version 24"

# mkdir -p /app
# validate "$?" "creating app directory"


USERNAME="expense"

if id -u "$USERNAME" >/dev/null 2>&1; then
    echo "User '$USERNAME' already exists. Skipping creation."
else
    echo "Creating system user '$USERNAME'..."
    useradd --system --home /app --shell /sbin/nologin --comment "expense system user" "$USERNAME" &>> "$LOG_FILE"
    echo "User '$USERNAME' created successfully."
    validate "$?" "creating systemuser expense"
fi


# FILE="/tmp/backend.tar.gz"

# if [ -f "$FILE" ]; then
#     echo "$FILE already exists. Skipping download."
# else
#     curl -o "$FILE" https://raw.githubusercontent.com/daws-92s/expense-documentation/refs/heads/main/artifacts/expense-backend-v5.tar.gz
#     validate "$?" "downloading expense code"
# fi

curl -o /tmp/backend.tar.gz https://raw.githubusercontent.com/daws-92s/expense-documentation/refs/heads/main/artifacts/expense-backend-v5.tar.gz
validate "$?" "downloading expense code"

rm -rf /app/*
validate "$?" "cleaned /app directory"

mkdir -p /app
validate "$?" "created /app directory"

tar -xzf /tmp/backend.tar.gz -C /app
validate "$?" "extracting the code in app directory"

cd /app
npm install &>> "$LOG_FILE"
validate "$?" "installing dependencies"


cp "$SCRIPT_DIR"/backend.service /etc/systemd/system/backend.service
validate "$?" "copying backend file to systemd"


dnf install mysql -y &>> "$LOG_FILE"
validate "$?" "installing mysql client"

DB_EXISTS=$(mysql -h database.srikarlabs.space -u root -p'ExpenseApp@1' -sse "SHOW DATABASES LIKE 'transactions';")

if [ "$DB_EXISTS" == "transactions" ]; then
    echo "Schema already loaded. Skipping."
else
    mysql -h database.srikarlabs.space -u root -p'ExpenseApp@1' < /app/schema/backend.sql
    validate "$?" "load schema data to mysql server"
fi

# mysql -h database.srikarlabs.space -u root -p'ExpenseApp@1' < /app/schema/backend.sql
# Takes all the file content from backend.sql and pastes on mysql prompt 
# when you give < it does not copy the file/folder it copies the fie content

systemctl daemon-reload
validate "$?" "daemon-reload"

systemctl enable backend
systemctl start backend
validate "$?" "start and enable server"

echo "================================="
echo "Script completed at: $(date)" | tee -a "$LOG_FILE"
echo "================================="

echo "Script took $SECONDS Seconds to complete"



# SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# I'm expanding the script correct if it is wrong
# when i give "$0" it takes path /home/ec2-user/expense-app-v1-v2/expense-v1/backend-nginx.sh
# when i give it with dirname "$0" it takes path /home/ec2-user/expense-app-v1-v2/expense-v1
# last one is stripped from the path
# and then it is giving cd  /home/ec2-user/expense-app-v1-v2/expense-v1 and checking for pwd which also prints the same /home/ec2-user/expense-app-v1-v2/expense-v1