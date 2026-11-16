#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LOGS_FOLDER="/var/log/expense"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1) 
#here script_name captures frontend. .. $0 is the special variable which takes the script name and where we are seperating frontend.sh with (.).
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S) 
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME-$TIMESTAMP.log"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
BR="\e[1;31m"
BG="\e[1;32m"
RESET="\e[0m"
mkdir -p "$LOGS_FOLDER"

# example file created in this way frontend-2026-11-16-23-07-00.log

user_id=$(id -u)

if [ $user_id -ne 0 ]; then
    echo -e "${BR}ERROR${RESET}: please run with sudo access" 
    exit 1
fi

echo "configure frontend nginx"
echo "----------------------------"

timestamp(){
    date +"%d-%b-%Y-%I-%M-%S-%p"
}

validate(){
    exitstatus=$1
    description=$2
    if [ "$exitstatus" -ne 0 ]; then
        echo -e "$(timestamp) ${R}[ERROR]${RESET} ${description}..${R}FAILED${RESET}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "$(timestamp) ${BG}[INFO]${RESET} ${description}..${BG}SUCCESS${RESET}" | tee -a "$LOG_FILE"
    fi
}


echo "Script started at: $(date)" | tee -a "$LOG_FILE"
echo "================================="

dnf install nginx -y &>> "$LOG_FILE" 
validate "$?" "installing nginx"

systemctl enable nginx
systemctl start nginx
validate "$?" "enable and start nginx"

rm -rf /usr/share/nginx/html/* &>> "$LOG_FILE"
validate "$?" "removing default content from nginx html folder"


curl -o /tmp/frontend.tar.gz https://raw.githubusercontent.com/daws-92s/expense-documentation/refs/heads/main/artifacts/expense-frontend-v5.tar.gz
validate "$?" "downloading frotend nginx code"

cd /usr/share/nginx/html
tar -xzf /tmp/frontend.tar.gz
validate "$?" "copy the code to nginx html"

cp "$SCRIPT_DIR"/expense.conf /etc/nginx/default.d/
validate "$?" "copying configuration file to default.d"

nginx -t
validate "$?" "checking nginx configuration file"

systemctl restart nginx &>> "$LOG_FILE"
validate "$?" "restart nginx"


echo "================================="
echo "Script completed at: $(date)" | tee -a "$LOG_FILE"

echo "================================="
echo "Script took $SECONDS Seconds to complete"

