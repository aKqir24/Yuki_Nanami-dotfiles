#!/bin/bash

function volume_output() {
	if [[ $(pactl get-sink-mute @DEFAULT_SINK@) == "Mute: yes" ]]; then
		echo MUTED
	else
		pactl get-sink-volume @DEFAULT_SINK@ | awk '{print $5}' | tr -d '\n'
	fi
}

volume_option() {
    case "$1" in
        --get-volume) 
            volume_output ;;

        --mute-toggle)
            pactl set-sink-mute @DEFAULT_SINK@ toggle
            echo "MUTED!!"  # This line will only print when toggling mute
            ;;
        -h) echo "-v(volume_controls): --get-volume, --mute-toggle"; exit 1 ;;
        *) echo "Invalid option. Use --get-volume or --mute-toggle."; exit 1 ;;
    esac
}

# Print Disk Usage in Percentage for Multiple Partitions (No Directory, Option to Merge)
disk_usage_percentage() {
    # If no disks are specified, use root partition by default
    partitions=("$@")
    if [ ${#partitions[@]} -eq 0 ]; then
        partitions=("/")
    fi

    total_used=0
    total_size=0

    for partition in "${partitions[@]}"; do
        # Check if partition exists
        if df "$partition" &>/dev/null; then
            # Calculate disk usage in percentage
            usage=$(df "$partition" | awk 'NR==2 {used=$3; total=$2} END {print used/total * 100}')
            
            total_used=$(echo "$total_used + $usage" | bc)
            total_size=$((total_size + 1)) # count partitions
        else
            echo "Partition $partition not found!"
        fi
    done

    # If merging, output total percentage
    if [ "$total_size" -gt 1 ]; then
        merged_percentage=$(echo "$total_used / $total_size" | bc)
        # Limit to two decimal places, only show if non-zero
        if [[ $(echo "$merged_percentage" | awk '{print int($1)}') == "$merged_percentage" ]]; then
            echo "Merged disk usage: ${merged_percentage%.*}%"
        else
            echo "Merged disk usage: $(printf "%.2f" $merged_percentage)%"
        fi
    else
        # Limit to two decimal places, only show if non-zero
        if [[ $(echo "$total_used" | awk '{print int($1)}') == "$total_used" ]]; then
            echo "$total_used%"
        else
            echo "$(printf "%.2f" $total_used)%"
        fi
    fi
}

# Print Disk Usage in Size (GB/MB) for Multiple Partitions (No Directory, Option to Merge)
disk_usage_size() {
    # If no disks are specified, use root partition by default
    partitions=("$@")
    if [ ${#partitions[@]} -eq 0 ]; then
        partitions=("/")
    fi

    total_used=0
    total_size=0
    size_unit="GB"

    for partition in "${partitions[@]}"; do
        # Check if partition exists
        if df "$partition" &>/dev/null; then
            # Display disk usage in human-readable format (GB/MB)
            used=$(df -h "$partition" | awk 'NR==2 {print $3}')
            total=$(df -h "$partition" | awk 'NR==2 {print $2}')
            
            # Remove the unit for calculation
            used_value=$(echo $used | sed 's/[A-Za-z]//g')
            total_value=$(echo $total | sed 's/[A-Za-z]//g')
            
            used_unit=$(echo $used | sed 's/[0-9]//g')
            total_unit=$(echo $total | sed 's/[0-9]//g')

            # Convert units to consistent units (GB/MB)
            if [[ "$used_unit" == "M" ]]; then
                used_value=$(echo "scale=2; $used_value / 1024" | bc)
                size_unit="GB"
            elif [[ "$used_unit" == "K" ]]; then
                used_value=$(echo "scale=2; $used_value / 1000000" | bc)
            fi

            if [[ "$total_unit" == "M" ]]; then
                total_value=$(echo "scale=2; $total_value / 1024" | bc)
                size_unit="GB"
            elif [[ "$total_unit" == "K" ]]; then
                total_value=$(echo "scale=2; $total_value / 1000000" | bc)
            fi

            total_used=$(echo "$total_used + $used_value" | bc)
            total_size=$(echo "$total_size + $total_value" | bc)
        else
            echo "Partition $partition not found!"
        fi
    done

    # If merging, output total size
    if [ "$total_size" -gt 1 ]; then
        merged_size=$(echo "$total_used" | bc)
        # Limit to two decimal places, only show if non-zero
        if [[ $(echo "$merged_size" | awk '{print int($1)}') == "$merged_size" ]]; then
            echo "Merged disk usage: ${merged_size%.*} $size_unit used / $total_size $size_unit total"
        else
            echo "Merged disk usage: $(printf "%.2f" $merged_size) $size_unit used / $(printf "%.2f" $total_size) $size_unit total"
        fi
    else
        # Limit to two decimal places, only show if non-zero
        if [[ $(echo "$total_used" | awk '{print int($1)}') == "$total_used" ]]; then
            echo "$total_used $size_unit used / $total_size $size_unit total"
        else
            echo "$(printf "%.2f" $total_used) $size_unit used / $(printf "%.2f" $total_size) $size_unit total"
        fi
    fi
}

# Optimized CPU Usage (using /proc/stat)

cpu_usage() {
    # Get the CPU usage from the top command, parsing the output
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # Round the value and check if it's an integer
    rounded_cpu_usage=$(printf "%.0f" $cpu_usage)
    
    if [[ "$cpu_usage" == "$rounded_cpu_usage" ]]; then
        # If the rounded value matches the original, print without decimals
        printf "%d%%\n" $rounded_cpu_usage
    else
        # Otherwise, print with two decimal places
        printf "%.2f%%\n" $cpu_usage
    fi
}

# RAM Usage in Percentage
ram_usage_percentage() {
	echo "$(free -m | awk '/Mem/ {print int($3/$2 * 100)}')%"
}

# RAM Usage in Size (GB/MB)
ram_usage_size() {
    free -m | awk '/Mem/ {used=$3; total=$2} END {
        used_gb=used/1024;
        total_gb=total/1024;
        if (used<=1024) print used "MB used / " total "MB total";
        else print used_gb "GB used / " total_gb "GB total"
    }'
}

# Parse Command-Line Arguments
case "$1" in
    -v) volume_option "$2" ;;
    -du) 
        if [[ "$2" == "--size" ]]; then
            # If --size is specified, use disk_usage_size
            disk_usage_size "${@:3}"
        elif [[ "$2" == "--percentage" ]]; then
            # If --percentage is specified, use disk_usage_percentage
            disk_usage_percentage "${@:3}"
        else
            # Default to percentage if no option is given
            disk_usage_percentage "${@:2}"
        fi
        ;;
    -cu) cpu_usage ;;
    -ru) 
        if [[ "$2" == "--size" ]]; then
            ram_usage_size
        elif [[ "$2" == "--percentage" ]]; then
            ram_usage_percentage
        else
            ram_usage_percentage
        fi
        ;;
    *) 
        echo "Usage: 
        -v(volume_controls): --get-volume, --mute-toggle
        -du (disk_usage_percentage) [--size or --percentage] [partition1 partition2 ...]
        -cu (cpu_usage)
        -ru (ram_usage_percentage) [--size or --percentage]"
        ;;
esac
