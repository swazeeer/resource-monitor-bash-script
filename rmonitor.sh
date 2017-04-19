#!/bin/bash
########################################
## Author: swazeeer
## Date Written: July 24, 2016
## Date Modified: July 25, 2016
## 
## Purpose: a super-duper resource monitor that displays
## cpu and memory usage graphs, header (time, cpu usage, memory stats),
## 5 most cpu-intensive processes, root partition space, disk traffic,
## network traffic.
#########################################

MEMgraph=()
CPUgraph=()
downloadUsage=(1 1)
uploadUsage=(1 1)
DiskRead=(1 1)
DiskWrite=(1 1)
length=75
total_uptimes=(1 1)
total_idle_times=(1 1)

# kilobytes written to disk per refresh cycle (~1 second)
# very first output displays kilobytes written since start up
diskW() {
	DiskWrite+=("$1")
	local n1=${DiskWrite[-1]}
	local n2=${DiskWrite[-2]}
	local interval=$((n1-n2))
	local bb=$(((interval*512)/1024))	
	echo $bb "Kilobytes Written"
}


# kilobytes read per refresh cycle (~1 second)
# very first output displays kilobytes read since start up
diskR() {
	DiskRead+=("$1")
	local n1=${DiskRead[-1]}
	local n2=${DiskRead[-2]}
	local interval=$((n1-n2))
	#interval represents the number of sectors
	# which is multiplied by 512 bytes (1 sector = 512 bytes)
	local bb=$(((interval*512)/1024))
	echo -n $bb "Kilobytes Read     " 
}

#kilobytes uploaded  per refresh cycle (~1 second)
# very first output displays kilobytes uploaded since start up
upload() {
	uploadUsage+=("$1")
	local n1=${uploadUsage[-1]}
	local n2=${uploadUsage[-2]}
	local interval=$((n1-n2))
	local kb=$((interval/1024))
	echo  $kb  KiloBytes Uploaded
}

#kilobytes downloaded  per refresh cycle (~1 second)
# very first output displays kilobytes downloaded since start up
download() {
	downloadUsage+=("$1")
	local n1=${downloadUsage[-1]}
	local n2=${downloadUsage[-2]}
	local interval=$((n1-n2))
	local kb=$((interval/1024))
	echo -n $kb  KiloBytes "Downloaded     "
}


header() {
	echo `date +"%l:%M %p"` CPU: $1% MEM: $2 K total, $3 K "free"
}

mostCPU() {
	echo "  PID USER STATE %CPU %MEM COMMAND"
	echo "$1"
}


usageMEM() {	
	used_mem=$(($1-$2))	
	decimal=$(bc <<< "scale=2;$used_mem/$1")
	stars=$(bc <<< "$decimal*5")
	roundedstar=`echo $stars | awk '{print int($1+0.5)}'`
	
	counter=$roundedstar

	while [ "$roundedstar" != "0" ]
	do
		MEMgraph[$roundedstar]+="*"
		((roundedstar--))
	done

	while [ "$counter" != "5" ]
	do
		((counter++))	
		MEMgraph[$counter]+="."
	done

	if [ "$3"  == "1" ]
	then
		echo  'Memory Usage'
		printf "%"$length"s\n" "${MEMgraph[5]:${#MEMgraph[5]}<$length?0:-$length}"	
		printf "%"$length"s\n" "${MEMgraph[4]:${#MEMgraph[4]}<$length?0:-$length}"	
		printf "%"$length"s\n" "${MEMgraph[3]:${#MEMgraph[3]}<$length?0:-$length}"
		printf "%"$length"s\n" "${MEMgraph[2]:${#MEMgraph[2]}<$length?0:-$length}"
		printf "%"$length"s\n" "${MEMgraph[1]:${#MEMgraph[1]}<$length?0:-$length}"
		echo 
	fi
}


usageCPU() {
	percent_non_idle_time=$1
	if [ $percent_non_idle_time -eq 0 ]
	then
		CPUgraph[5]+="."
		CPUgraph[4]+="."
		CPUgraph[3]+="."
		CPUgraph[2]+="."
		CPUgraph[1]+="."			
		
	elif [ $percent_non_idle_time  -gt 0 -a $percent_non_idle_time  -lt 21  ]
	then
		CPUgraph[5]+="."
		CPUgraph[4]+="."
		CPUgraph[3]+="."
		CPUgraph[2]+="."
		CPUgraph[1]+="*"			
	
	elif [ $percent_non_idle_time -gt 20 -a $percent_non_idle_time  -lt 41 ]
	then 
		CPUgraph[5]+="."
		CPUgraph[4]+="."
		CPUgraph[3]+="."
		CPUgraph[2]+="*"
		CPUgraph[1]+="*"
	elif [ $percent_non_idle_time -gt 40 -a $percent_non_idle_time  -lt 61  ]
	then
		CPUgraph[5]+="."
		CPUgraph[4]+="."
		CPUgraph[3]+="*"
		CPUgraph[2]+="*"
		CPUgraph[1]+="*"
	elif [ $percent_non_idle_time -gt 60 -a $percent_non_idle_time  -lt 81  ]
	then 
		CPUgraph[5]+="."
		CPUgraph[4]+="*"
		CPUgraph[3]+="*"
		CPUgraph[2]+="*"
		CPUgraph[1]+="*"
	elif [ $percent_non_idle_time -gt 80  ]
	then 
		tput setf 4		
		CPUgraph[5]+="*"
		CPUgraph[4]+="*"
		CPUgraph[3]+="*"
		CPUgraph[2]+="*"
		CPUgraph[1]+="*"
	fi
	
	if [ "$2"  == "1" ]
	then
		echo  'CPU Usage'
		printf "%"$length"s\n" "${CPUgraph[5]:${#CPUgraph[5]}<$length?0:-$length}" 	
		printf "%"$length"s\n" "${CPUgraph[4]:${#CPUgraph[4]}<$length?0:-$length}"	
		printf "%"$length"s\n" "${CPUgraph[3]:${#CPUgraph[3]}<$length?0:-$length}"
		printf "%"$length"s\n" "${CPUgraph[2]:${#CPUgraph[2]}<$length?0:-$length}"
		printf "%"$length"s\n" "${CPUgraph[1]:${#CPUgraph[1]}<$length?0:-$length}"
		echo
	fi
}


commands () {
	# 5 most cpu-intensive programs
	intensePROC="`ps -eo pid,user,state,pcpu,pmem,comm  | sort -rn -k 4 | head -5`"

	memtotal=` grep "MemTotal: " /proc/meminfo | awk '{ print $2}'`
	memfree=` grep "MemFree: " /proc/meminfo | awk '{ print $2}'`
	
	# total download form major interfaces
	downld=`grep -e "lo:" -e "wlan0:" -e "eth0" /proc/net/dev  | awk '{print $2}' | paste -sd+ - | bc`	
	# total upload form major interfaces
	upld=`grep -e "lo:" -e "wlan0:" -e "eth0" /proc/net/dev | awk '{print $10}' | paste -sd+ - | bc`
	# storage information for root partition
	disk="`df -h | grep "/$" | awk '{print $2 "   "$3 "  " $4 "  " $5}'`"
	
	# sectors read since start up 
	readDisk=`grep " sda "     /proc/diskstats | awk '{print $6 }'`

	# sectors write since start up	
	writtenDisk=` grep " sda " /proc/diskstats | awk '{print  $10 }'`

	#cpu calculations
	total=`grep "cpu "  "/proc/stat"  | awk '{print $2 + $3 + $4 + $5+ $6 + $7 + $8 }'`
	idle=`grep "cpu "  "/proc/stat"  | awk '{print $5 }'`
	total_uptimes+=("$total")
	total_idle_times+=("$idle")
		
	interval_duration=$((total_uptimes[-1]-total_uptimes[-2]))
	idle_time_during_interval=$((total_idle_times[-1]-total_idle_times[-2]))
	non_idle_interval=$((interval_duration-idle_time_during_interval))
	
	fract_non_idle_time_during_interval=$(bc <<< "scale=3;$non_idle_interval/$interval_duration")
	percent_non_idle_time=`echo $fract_non_idle_time_during_interval | awk '{print int($1*100)}'`
	#cpu calculations

	tput cup 0 0
	tput ed	
	
	if [ "$1"  == "1" ]
	then
		tput cup 0 0 	
		tput ed 
		header $percent_non_idle_time	$memtotal $memfree

	fi
	usageCPU $percent_non_idle_time $2
	usageMEM $memtotal $memfree $3

	if [ "$4"  == "1" ]
	then
		echo  'Most CPU-Intensive Processes'
		mostCPU "$intensePROC"
		echo
	fi

	if [ "$6"  == "1" ]
	then
		echo 'Network Traffic'
		download $downld
		upload $upld
		echo
	fi

	if [ "$7"  == "1" ]
	then
		echo 'Root Partition Space'
		echo Total  Used  Free %Used		
		echo "$disk"
		echo 
	fi

	if [ "$8"  == "1" ]
	then
		echo 'Disk Traffic'
		diskR $readDisk
		diskW $writtenDisk
		echo 
	fi


	if [ "$5"  == "1" ]
	then
		echo -e  'Options:
h)  Show/Hide The Header
c)  Show/Hide CPU Usage
m)  Show/Hide Memory Usage				
p)  Show/Hide Most CPU-Intensive Processes
d)  Show/Hide Disk Space
t)  Show/Hide Disk Traffic
n)  Show/Hide Network Usage
o)  Show/Hide The List of Options
q)  Quit' 		
	fi
}


optionH=0
optionC=0
optionM=0
optionP=0
optionO=1
optionD=0
optionN=0
optionT=0
tput clear
while [ "$value"  != "q" ] 
do
	read -s -rt 1 -n 1 value	
	
	if [ "$value" == 'h' -a "$optionH" == "0" ]; 
	then 
		optionH="1"
	elif [ "$value" == 'h'   -a "$optionH" == "1" ]; 
	then 
		optionH="0"
	fi

	if [ "$value" == "c" -a "$optionC" == "0" ]; 
	then 
		 optionC="1"
	elif [  "$value"  == "c" -a  "$optionC" == "1" ]; 
	then 
		 optionC="0"
	fi

	if [ "$value" == "m" -a "$optionM" == "0" ]; 
	then 
		 optionM="1"
	elif [ "$value" == "m" -a  "$optionM" == "1" ]; 
	then 
		 optionM="0"
	fi

	if [ "$value" == "p" -a "$optionP" == "0" ]; 
	then 
		 optionP="1"
	elif [ "$value" == "p" -a  "$optionP" == "1" ]; 
	then 
		 optionP="0"
	fi

	if [ "$value" == "o" -a "$optionO" == "0" ]; 
	then 
		 optionO="1"
	elif [ "$value" == "o" -a  "$optionO" == "1" ]; 
	then 
		 optionO="0"
	fi

	if [ "$value" == "n" -a "$optionN" == "0" ]; 
	then 
		 optionN="1"
	elif [ "$value" == "n" -a  "$optionN" == "1" ]; 
	then 
		 optionN="0"
	fi

	if [ "$value" == "d" -a "$optionD" == "0" ]; 
	then 
		 optionD="1"
	elif [ "$value" == "d" -a  "$optionD" == "1" ]; 
	then 
		 optionD="0"
	fi

	if [ "$value" == "t" -a "$optionT" == "0" ]; 
	then 
		 optionT="1"
	elif [ "$value" == "t" -a  "$optionT" == "1" ]; 
	then 
		 optionT="0"
	fi
	commands $optionH $optionC $optionM $optionP $optionO $optionN $optionD $optionT

done 
exit 0
