#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

##### Variablen

devices=("/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" "/dev/sdf" "/dev/sdg" "/dev/sdh" "/dev/sdi" "/dev/sdj" "/dev/sdk" "/dev/sdl" "/dev/sdm" "/dev/sdn" "/dev/sdo" "/dev/sdp")
partitions=("/dev/sdb1" "/dev/sdc1" "/dev/sdd1" "/dev/sde1" "/dev/sdf1" "/dev/sdg1" "/dev/sdh1" "/dev/sdi1" "/dev/sdj1" "/dev/sdk1" "/dev/sdl1" "/dev/sdm1" "/dev/sdn1" "/dev/sdo1" "/dev/sdp1")
mountpoint="/mnt/md"
username="stoertebeker"
##### Parametercheck

echo RAID-Typ: $1
echo Anzahl HDDs: $2

##### Script

## Partitonstabelle erstellen
for ((i=0;i<"$2";i++))
do
        echo parted "${devices[$i]}" mklabel gpt
done

## Partitionen erstellen
for ((i=0;i<"$2";i++))
do
        echo parted -a optimal -- "${devices[$i]}" mkpart primary 2048s -8192s
done

## Partition als RAID-Partition markieren
for ((i=0;i<"$2";i++))
do
        echo parted "${devices[$i]}" set 1 raid on
done

## Devices zusammenzählen
for ((i=0;i<"$2";i++))
do
	devparms+=("${devices[$i]}")
done

## RAID erzeugen
echo mdadm --create /dev/md0 --auto md --level=$1 --raid-devices=$2 ${devparms[@]}

## RAID5/6 Chunks
#TODO

## Dateisystem erzeugen
echo mkfs.ext4 /dev/md0 

## mounten
echo mount /dev/md0 $mountpoint
echo chown $username":"$username $mountpoint

### Warteschleife, bis RAID fertig initialisiert ist
fertig=0

##Initialisieren beschleunigen
echo "echo 200000 > /proc/sys/dev/raid/speed_limit_min"

while [ $fertig -eq 0 ]
do
#status=$(mdadm -D /dev/md0 | head -12l | tail -1l | cut -d: -f2 | cut -d, -f 1)
status="$(grep -Po "(?<=State : ).*(?=.)" < <(sudo mdadm -D /dev/md0))"
if [ "$status" == "clean" ]
	then
		echo "RAID clean!"
		sleep 5
		status="$(grep -Po "(?<=State : ).*(?=.)" < <(sudo mdadm -D /dev/md0))"
		fertig=1
	else
		echo "processing"
		status="$(grep -Po "(?<=State : ).*(?=.)" < <(sudo mdadm -D /dev/md0))"
		sleep 5
fi
done
##Beschleunigung für Initialisierung zurücksetzen
echo "echo 1000 > /proc/sys/dev/raid/speed_limit_min"

## Benchmark
echo Benchmark ...
#fio-bench.sh raid$1-devices$2
sleep 2

### RAID abbauen
echo umount /dev/md0
echo mdadm --stop /dev/md0 

##Superblöcke löschen
echo mdadm --zero-superblock ${devparms[@]}
