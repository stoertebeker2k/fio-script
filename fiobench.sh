#!/bin/bash
echo "Benchmark-Script"
echo
#####Variablen
#Blockgröße
size1=("1m" "4m")
#Benchmarkpfad
directory1="/mnt/md/"
#Lese/Schreib-Option
readwrite1=("read" "write")
#Anzahl der Durchläufe für Mittelwert
runs=3
#Counter-Variable (nicht verändern!)
i=0

#####Funktionen
benchmark(){
        size="$blksize" directory=${directory1} readwrite="$rwwert" fio benchmark.fio 2>&1 > tmp/output_"$blksize"_"$rwwert".txt
        wert=$(sed -n 's/.*aggrb=//; 15 s/K.*//p'  tmp/output_"$blksize"_"$rwwert".txt)
	echo $(($wert/1024)) MB/s
        zwischenwert=$(($zwischenwert + $wert))
}

requirements(){
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' fio|grep "install ok installed")
	echo Checking for fio: $PKG_OK
	if [ "" == "$PKG_OK" ]; then
	  echo "No fio. Installing."
	  sudo apt-get --force-yes --yes install fio
	fi
}
tmpfolder(){
	if [ ! -d ./tmp ]
	  then
	    mkdir ./tmp
	fi
}
#####Script

requirements

tmpfolder

for rwwert in ${readwrite1[@]}
  do
    for blksize in ${size1[@]}
      do
	echo Benchmark für bs="$blksize" mit rw="$rwwert"
	while [ $i -lt $runs ]
	  do
	    echo Durchlauf Nr. $(($i+1))
	    benchmark
	    i=$(( $i + 1 ))
	  done
	result=$(($zwischenwert/$runs))
	echo Mittelwert: $(($result/1024)) MB/s
	echo "##################"
	
	result=0
	i=0
	zwischenwert=0
    done
done

rm tmp/output*.txt
rmdir tmp
