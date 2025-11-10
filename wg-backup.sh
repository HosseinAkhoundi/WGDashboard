#!/bin/bash


while [[ -z "$tk" ]]; do
    echo "Bot token: "
    read -r tk
    if [[ $tk == $'\0' ]]; then
        echo "Invalid input. Token cannot be empty."
        unset tk
    fi
done


while [[ -z "$chatid" ]]; do
    echo "Chat id: "
    read -r chatid
    if [[ $chatid == $'\0' ]]; then
        echo "Invalid input. Chat id cannot be empty."
        unset chatid
    elif [[ ! $chatid =~ ^\-?[0-9]+$ ]]; then
        echo "${chatid} is not a number."
        unset chatid
    fi
done


echo "Caption (for example, your domain, to identify the database file more easily): "
read -r caption


while true; do
    echo "Cronjob (minutes and hours) (e.g : 30 6 or 0 12) : "
    read -r minute hour
    if [[ $minute == 0 ]] && [[ $hour == 0 ]]; then
        cron_time="0 0 * * *"
        break
    elif [[ $minute == 0 ]] && [[ $hour =~ ^[0-9]+$ ]] && [[ $hour -lt 24 ]]; then
        cron_time="0 */${hour} * * *"
        break
    elif [[ $hour == 0 ]] && [[ $minute =~ ^[0-9]+$ ]] && [[ $minute -lt 60 ]]; then
        cron_time="*/${minute} * * * *"
        break
    elif [[ $minute =~ ^[0-9]+$ ]] && [[ $hour =~ ^[0-9]+$ ]] && [[ $hour -lt 24 ]] && [[ $minute -lt 60 ]]; then
        cron_time="*/${minute} */${hour} * * *"
        break
    else
        echo "Invalid input, please enter a valid cronjob format (minutes and hours, e.g: 0 6 or 30 12)"
    fi
done


while [[ -z "$crontabs" ]]; do
    echo "Would you like the previous crontabs to be cleared? [y/n] : "
    read -r crontabs
    if [[ $crontabs == $'\0' ]]; then
        echo "Invalid input. Please choose y or n."
        unset crontabs
    elif [[ ! $crontabs =~ ^[yn]$ ]]; then
        echo "${crontabs} is not a valid option. Please choose y or n."
        unset crontabs
    fi
done

if [[ "$crontabs" == "y" ]]; then
sudo crontab -l | grep -vE '/root/ac-backup.+\.sh' | crontab -
fi


# Check if WireGuard directories exist
if [ ! -d "/etc/wireguard" ]; then
    echo "Error: /etc/wireguard directory does not exist."
    exit 1
fi

if [ ! -d "/root/WGDashboard/src/db" ]; then
    echo "Warning: /root/WGDashboard/src/db directory does not exist."
    echo "Backup will only include /etc/wireguard"
fi

# Set ZIP command based on which directories exist
if [ -d "/root/WGDashboard/src/db" ]; then
    ZIP="zip -r /root/ac-backup-wg.zip /etc/wireguard /root/WGDashboard/src/db"
else
    ZIP="zip -r /root/ac-backup-wg.zip /etc/wireguard"
fi

ACLover="WireGuard backup"


trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

IP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
caption="${caption}\n\n${ACLover}\n<code>${IP}</code>\nCreated by @AC_LoverBot - https://github.com/AC-Lover/backup"
comment=$(echo -e "$caption" | sed 's/<code>//g;s/<\/code>//g')
comment=$(trim "$comment")


sudo apt install zip -y

cat > "/root/ac-backup-wg.sh" <<EOL
#!/bin/bash

rm -f /root/ac-backup-wg.zip
$ZIP
echo -e "$comment" | zip -z /root/ac-backup-wg.zip
curl -F chat_id="${chatid}" -F caption=\$'${caption}' -F parse_mode="HTML" -F document=@"/root/ac-backup-wg.zip" https://api.telegram.org/bot${tk}/sendDocument
EOL



{ crontab -l -u root; echo "${cron_time} /bin/bash /root/ac-backup-wg.sh >/dev/null 2>&1"; } | crontab -u root -


bash "/root/ac-backup-wg.sh"

echo -e "\nDone\n"
