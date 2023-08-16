  #!/bin/bash

  clear
  echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"

  # Your credentials
  apikey=""
  ip=""
  bot_token=""
  chat_id=""

  while true; do
    # Menu options
    echo "1) Add Group"
    echo "2) Start Group Scan"
    echo "3) Delete Group"
    echo "4) Exit"

    # Get user's choice
    read -p "Enter your choice [1-4]: " choice

    # Perform action based on user's choice
    if [ $choice -eq 1 ]
    then
      while true; do
        clear
        echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"
        read -p "Enter Group Name: " target_name
        if [[ -z "$target_name" ]]; then
          echo "Please enter a valid name"
        elif [[ $target_name =~ [^a-zA-Z0-9] ]]; then
          echo "Please use only letters and numbers"
        else
          response=$(curl -s -k -X GET -H "X-Auth: $apikey" "https://$ip:3443/api/v1/target_groups")
          if echo "$response" | grep -q "$target_name"; then
            echo "Duplicate Target, please enter a different name"
          else
            echo "Success"
            clear
            curl_response=$(curl -s -k -X $'POST' \
              -H $'Host: '$ip':3443' -H $'Content-Type: application/json' -H $'Accept: application/json, text/plain, */*' -H $'X-Auth: '$apikey \
              --data-binary '{"name":"'$target_name'","description":""}' \
              $'https://'$ip':3443/api/v1/target_groups')
            group_id=$(echo $curl_response | grep -o '"group_id":.*[^"]' | sed 's/"group_id": "//g' | tr -d '" }')

            while IFS='' read -r line || [[ -n "$line" ]]; do
              curl_response=$(curl -s -k -X $'POST' \
                -H $'Host: '$ip':3443' -H $'Content-Type: application/json' -H $'X-Auth: '$apikey \
                --data-binary '{"targets":[{"address":"'$line'","description":""}],"groups":["'$group_id'"]}' \
                $'https://'$ip':3443/api/v1/targets/add')
            done < "hosts.txt"
            echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"
            echo "All addresses added"
            curl -s -X POST https://api.telegram.org/bot$bot_token/sendMessage -d chat_id=$chat_id -d text="All addresses added, Let's configure" > /dev/null
            break
          fi
        fi
      done
    #Scan Speed
    clear
    echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"
    echo "Select a scan speed:"
    echo "1. Slow"
    echo "2. Fast"
    echo "3. Moderate"
    echo "4. Sequential"
    while true; do
      read -p "Enter a number (default: 2): " speed_choice
      case "$speed_choice" in
        "1")
          scan_speed="slow"
          break
          ;;
        "2"| "")
          scan_speed="fast"
          break
          ;;
        "3")
          scan_speed="moderate"
          break
          ;;
        "4")
          scan_speed="sequential"
          break
          ;;
        *)
          echo "Invalid choice: $speed_choice"
          continue
          ;;
      esac
      echo "Your Choice Speed: $scan_speed"
      break
    done
    echo "Selected scan speed: $scan_speed"

    response=$(curl -s -k -X GET -H "Host: $ip:3443" -H "User-Agent: Mozilla" -H "Content-Type: application/json" -H "Accept: application/json, text/plain, */*" -H "X-Auth: $apikey" -H "Connection: close" "https://$ip:3443/api/v1/scanning_profiles")
    names=$(echo "$response" | grep -o '"name": *"[^"]*"' | sed 's/"name": "\(.*\)"/\1/g')
    profile_ids=$(echo "$response" | grep -o '"profile_id": *"[^"]*"' | sed 's/"profile_id": "\(.*\)"/\1/g')

    clear
    #Scan Profile update
    while true; do
      clear
      echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"
      echo "Available scanning profiles:"
      paste <(echo "$names") <(echo "$profile_ids") | nl -w1 -s'  '
      read -p "Select a scanning profile (Enter a number): " selection

      if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le $(echo "$names" | wc -l) ]]; then
        name=$(echo "$names" | sed -n "${selection}p")
        id=$(echo "$profile_ids" | sed -n "${selection}p")
        echo "Selected scanning profile: $name, profile_id: $id"
        break
      else
        echo "Invalid selection, please enter a number between 1 and $(echo "$names" | wc -l)"
      fi
    done

    curl -s -k -X GET -H "Host: $ip:3443" -H 'User-Agent: Mozilla' -H 'Content-Type: application/json' -H 'Accept: application/json, text/plain, */*' -H "X-Auth: $apikey" -H 'Connection: close' "https://$ip:3443/api/v1/target_groups/$group_id/targets" | jq -r '.target_id_list[]' > target_id_list.txt
    while read -r line; do
        target_id="$line"
        curl -s -k -X PATCH \
            -H "Host: $ip:3443" -H "Content-Type: application/json" -H "User-Agent: Mozilla" -H "X-Auth: $apikey" \
            -d '{"scan_speed":"'"$scan_speed"'","login":{"kind":"none"},"ssh_credentials":{"kind":"none"},"default_scanning_profile_id":"'"$id"'","sensor":false,"case_sensitive":"no","limit_crawler_scope":true,"excluded_paths":[],"authentication":{"enabled":false},"proxy":{"enabled":false},"technologies":[],"custom_headers":[],"custom_cookies":[],"ad_blocker":true,"debug":false,"skip_login_form":false,"restrict_scans_to_import_files":false,"client_certificate_password":"","user_agent":"","client_certificate_url":null,"issue_tracker_id":"","excluded_hours_id":null,"preseed_mode":""}' \
            "https://$ip:3443/api/v1/targets/$target_id/configuration"
    done < target_id_list.txt
    clear
    echo "Configuration Complete"
    curl -s -X POST https://api.telegram.org/bot$bot_token/sendMessage -d chat_id=$chat_id -d text="Configuration Complete, Let's Start Scan" > /dev/null
    while true; do
      read -p "Do you want to start the scan? (yes/no): " scan_choice
      case "$scan_choice" in
        "yes")
          response=$(curl -s -k -X GET -H "Host: $ip:3443" -H 'User-Agent: Mozilla' -H 'Content-Type: application/json' -H 'Accept: application/json, text/plain, */*' -H "X-Auth: $apikey" -H 'Connection: close' "https://$ip:3443/api/v1/target_groups")
          groups_id=$(echo "$response" | jq -r '.groups[] | "\(.name) (\(.group_id))"')
          echo "Groups:"
          echo "$groups_id" | cat -n
          read -p "Your Choice: " choice
          group=$(echo "$groups_id" | sed -n "${choice}s/.*(\(.*\))/\1/p")
          echo "Your Choice ID: $group"
          
          curl -s -k -X POST \
              -H "Host: $ip:3443" -H 'Content-Type: application/json' -H 'User-Agent: Mozilla' -H "X-Auth: $apikey" \
              --data-binary '{"profile_id":"'${id}'","incremental":false,"schedule":{"disable":false,"start_date":null,"time_sensitive":false}}' \
              "https://$ip:3443/api/v1/target_groups/$group/scan"
          rm  target_id_list.txt
          clear 
          echo "Scanning Started"
          # Note: You can comment out this code if you don't want to use it
          curl -s -X POST https://api.telegram.org/bot$bot_token/sendMessage -d chat_id=$chat_id -d text="Scan Started" > /dev/null
          break
          ;;
        "no")
          rm  target_id_list.txt
          exit 0
          ;;
        *)
          echo "Invalid choice: $scan_choice"
          ;;
      esac
    done
      exit

      elif [ $choice -eq 2 ]
      then
        response=$(curl -s -k -X GET -H "Host: $ip:3443" -H 'User-Agent: Mozilla' -H 'Content-Type: application/json' -H 'Accept: application/json, text/plain, */*' -H "X-Auth: $apikey" -H 'Connection: close' "https://$ip:3443/api/v1/target_groups")
        groups_id=$(echo "$response" | jq -r '.groups[] | "\(.name) (\(.group_id))"')
        clear
        echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"
        echo "Groups:"
        echo "$groups_id" | cat -n
        read -p "Your choice: " choice
        group=$(echo "$groups_id" | sed -n "${choice}s/.*(\(.*\))/\1/p")
        echo "Group ID of your choice: $group"
        clear
        echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"
        echo "Available scanning profiles:"
      
        response=$(curl -s -k -X GET -H "Host: $ip:3443" -H "User-Agent: Mozilla" -H "Content-Type: application/json" -H "Accept: application/json, text/plain, */*" -H "X-Auth: $apikey" -H "Connection: close" "https://$ip:3443/api/v1/scanning_profiles")
        names=$(echo "$response" | grep -o '"name": *"[^"]*"' | sed 's/"name": "\(.*\)"/\1/g')
        profile_ids=$(echo "$response" | grep -o '"profile_id": *"[^"]*"' | sed 's/"profile_id": "\(.*\)"/\1/g')
        
        clear
        #Scan Profile update
        while true; do
          echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"
          echo "Available scanning profiles:"
          paste <(echo "$names") <(echo "$profile_ids") | nl -w1 -s'  '
          read -p "Select a scanning profile (Enter a number): " selection
        
          if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le $(echo "$names" | wc -l) ]]; then
            name=$(echo "$names" | sed -n "${selection}p")
            id=$(echo "$profile_ids" | sed -n "${selection}p")
            echo "Selected scanning profile: $name, profile_id: $id"
            break
          else
            echo "Invalid selection, please enter a number between 1 and $(echo "$names" | wc -l)"
          fi
        done
        curl -s -k -X POST \
            -H "Host: $ip:3443" -H 'Content-Type: application/json' -H 'User-Agent: Mozilla' -H "X-Auth: $apikey" \
            --data-binary '{"profile_id":"'${id}'","incremental":false,"schedule":{"disable":false,"start_date":null,"time_sensitive":false}}' \
            "https://$ip:3443/api/v1/target_groups/$group/scan"
        clear
        echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"
        echo "Scanning Started"
          # Note: You can comment out this code if you don't want to use it
          curl -s -X POST https://api.telegram.org/bot$bot_token/sendMessage -d chat_id=$chat_id -d text="Scanning started" > /dev/null
        exit

      elif [ $choice -eq 3 ]
      then

          #Delete Group
          response=$(curl -s -k -X GET -H "Host: $ip:3443" -H 'User-Agent: Mozilla' -H 'Content-Type: application/json' -H 'Accept: application/json, text/plain, */*' -H "X-Auth: $apikey" -H 'Connection: close' "https://$ip:3443/api/v1/target_groups")
          groups_id=$(echo "$response" | jq -r '.groups[] | "\(.name) (\(.group_id))"')
          clear
          echo -e "\033[1;31mAcunetix Target Management Tool\033[0m"
          echo "Groups:"
          echo "$groups_id" | cat -n
          read -p "Your Choice $(echo "$groups_id" | wc -l)): " choice
          group=$(echo "$groups_id" | sed -n "${choice}s/.*(\(.*\))/\1/p")
          echo "Group ID of your choice: $group"

        curl -s -k -X GET -H "Host: $ip:3443" -H 'User-Agent: Mozilla' -H 'Content-Type: application/json' -H 'Accept: application/json, text/plain, */*' -H "X-Auth: $apikey" -H 'Connection: close' "https://$ip:3443/api/v1/target_groups/$group/targets" | jq -r '.target_id_list[]' > target_id_list_for_delete.txt
        while read -r line; do
        target_id_delete="$line"
        curl -s -k -X POST \
            -H "Host: $ip:3443" -H "Content-Type: application/json" -H "User-Agent: Mozilla" -H "X-Auth: $apikey" \
            --data-binary "{\"target_id_list\":[\"$target_id_delete\"]}" \
            "https://$ip:3443/api/v1/targets/delete"  
        done < target_id_list_for_delete.txt
        rm target_id_list_for_delete.txt

        curl -s -k -X POST -H "Host: ${ip}:3443" \
              -H "X-Auth: ${apikey}" \
              -H "Content-Type: application/json" \
              --data-binary "{\"group_id_list\":[\"$group\"]}" \
              "https://${ip}:3443/api/v1/target_groups/delete"
        clear
        echo "Target Group successfully deleted."
        # Note: You can comment out this code if you don't want to use it
        curl -s -X POST https://api.telegram.org/bot$bot_token/sendMessage -d chat_id=$chat_id -d text="Group Deleted" > /dev/null
      exit
      elif [ $choice -eq 4 ]
      then
      clear
      exit

      else
        clear
        echo "Invalid selection. Please try again."
      fi
  done
  ``