#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

##### Variablen

devices=("/dev/sdc" "/dev/sdd" "/dev/sde" "/dev/sdf" "/dev/sdg" "/dev/sdh" "/dev/sdi" "/dev/sdj" "/dev/sdk" "/dev/sdl" "/dev/sdm" "/dev/sdn" "/dev/sdo" "/dev/sdp")
partitions=("/dev/sdc1" "/dev/sdd1" "/dev/sde1" "/dev/sdf1" "/dev/sdg1" "/dev/sdh1" "/dev/sdi1" "/dev/sdj1" "/dev/sdk1" "/dev/sdl1" "/dev/sdm1" "/dev/sdn1" "/dev/sdo1" "/dev/sdp1")
mountpoint="/mnt/md"
username="stoertebeker"
##### Parametercheck

if [ -z "$1" ]
then
	echo "kein RAID-Typ angegeben!"
	echo "Korrekte Verwendung: ./raid-script.sh RAID-Typ Anzahl_Festplatten"
	exit 1
fi

if [ -z "$2" ]
then
        echo "Keine Festplattenanzahl angegeben!"
        echo "Korrekte Verwendung: ./raid-script.sh RAID-Typ Anzahl_Festplatten"
        exit 1
fi

echo RAID-Typ: $1
echo Anzahl HDDs: $2
sleep 1

##### Script

## Partitonstabelle erstellen
for ((i=0;i<"$2";i++))
do
        parted -s "${devices[$i]}" mklabel gpt
done

## Partitionen erstellen
for ((i=0;i<"$2";i++))
do
        parted -a optimal -- "${devices[$i]}" mkpart primary 2048s -8192s
done

## Partition als RAID-Partition markieren
for ((i=0;i<"$2";i++))
do
        parted "${devices[$i]}" set 1 raid on
done

## Devices zusammenzählen
for ((i=0;i<"$2";i++))
do
	devparms+=("${partitions[$i]}")
done

## RAID erzeugen
mdadm --create /dev/md0 --auto md -f --level=$1 --raid-devices=$2 ${devparms[@]}

## RAID5/6 Chunks
#TODO

## Dateisystem erzeugen
mkfs.ext4 /dev/md0 

## mounten
mount /dev/md0 $mountpoint
chown $username":"$username $mountpoint

### Warteschleife, bis RAID fertig initialisiert ist
fertig=0

##Initialisieren beschleunigen
echo 200000 > /proc/sys/dev/raid/speed_limit_min

while [ $fertig -eq 0 ]
do
#status=$(mdadm -D /dev/md0 | head -12l | tail -1l | cut -d: -f2 | cut -d, -f 1)
status="$(grep -Po "(?<=State : ).*(?=.)" < <(sudo mdadm -D /dev/md0))"
process="$(grep -Po "(?<=Resync Status : ).*(?=.)" < <(sudo mdadm -D /dev/md0))"
if [ "$status" == "clean" ] || [ "$status" == "active" ]
	then
		echo "RAID clean!"
		sleep 2
		fertig=1
	else
		echo "RAID-Status: $process"
		sleep 5
fi
done
##Beschleunigung für Initialisierung zurücksetzen
echo 1000 > /proc/sys/dev/raid/speed_limit_min

## Benchmark
echo Benchmark ...
./fiobench.sh
./fiobench.sh raid$1devices$2
sleep 2

### RAID abbauen
umount /dev/md0
mdadm --stop /dev/md0 

##Superblöcke löschen
mdadm --zero-superblock ${devparms[@]}
