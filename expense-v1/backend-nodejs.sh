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

echo "configure frontend nginx"
echo "----------------------------"

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


cp backend.service /etc/systemd/system/
validate "$?" "copying backend file to systemd"


dnf install mysql -y. &>> "$LOG_FILE"
validate "$?" "installing mysql client"

DB_EXISTS=$(mysql -h mysql.srikarlabs.space -u root -p'ExpenseApp@1' -sse "SHOW DATABASES LIKE 'transactions';")

if [ "$DB_EXISTS" == "transactions" ]; then
    echo "Schema already loaded. Skipping."
else
    mysql -h mysql.srikarlabs.space -u root -p'ExpenseApp@1' < /app/schema/backend.sql
    validate "$?" "load schema data to mysql server"
fi

# mysql -h mysql.srikarlabs.space -u root -p'ExpenseApp@1' < /app/schema/backend.sql
# Takes all the file content from backend.sql and pastes on mysql prompt 
# when you give < it does not copy the file/folder it copies the fie content

systemctl daemon-reload
validate "$?" "daemon-reload"

systemctl enable backend
systemctl start backend
validate "$?" "start and enable server"

echo "================================="
echo "Script completed at: $(date)" | tee -a "$LOG_FILE"

