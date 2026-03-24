#!/bin/bash

SCRIPT_DIR="./install-scripts"

if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Folder $SCRIPT_DIR not found"
    exit 1
fi

while true; do
    clear
    echo "===== Installation menu ====="

    mapfile -t scripts < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.sh")

    if [ ${#scripts[@]} -eq 0 ]; then
        echo "No script found in $SCRIPT_DIR"
        exit 1
    fi

    IFS=$'\n' scripts=($(sort <<<"${scripts[*]}"))
    unset IFS
    for i in "${!scripts[@]}"; do
        script_name=$(basename "${scripts[$i]}")
        name="${script_name%.sh}"
        echo "$((i+1))) $name"
    done

    echo "0) Exit"
    echo "============================"

    read -p "Your choice : " choix

    if [ "$choix" == "0" ]; then
        exit 0
    fi

    if [[ "$choix" =~ ^[0-9]+$ ]] && [ "$choix" -ge 1 ] && [ "$choix" -le ${#scripts[@]} ]; then
        selected_script="${scripts[$((choix-1))]}"
        echo "Execute $(basename "$selected_script")..."
        bash "$selected_script"
    else
        echo "Invalid choice"
    fi

    echo
    read -p "Press Enter to return to the menu"
done
