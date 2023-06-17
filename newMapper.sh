#!/bin/bash

### GLOBAL VARIABLE ###

#Example:
#IP="192.168.0."
#Currently works for /24 subnets
hostStart=
hostEnd=
#File for output
OUTPUT=""
#v2c Community
COMM="public"
# snmpwalk & snmpget. Modify these variables for v3.
WALK="snmpwalk -Cc -v2c -c $COMM"
GET="snmpget -v2c -c $COMM"
#If FQDN is relevant for you.
#DNSSERVER=""
#For converting PortList. Usable for polling VLANS.
#D2B=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})

### END GLOBAL VARIABLE ###

### FILE SETUP ###

rm $OUTPUT
touch $OUTPUT

### END FILE SETUP ###

### MAIN ###

### SCAN AVAILABLE HOSTS ###

### END SCAN ###


### CLEAR ARRAYS ###
entity=()
ifIndex=()
lldpLocalPortIndex=()
### END CLEAR ARRAYS ###


echo "Starting $host report!"
echo "$host" >> $OUTPUT


### BASE INFO ###
echo "Polling $host SysInfo!"

sysInfo=''
sysInfo=$($GET $host 1.3.6.1.2.1.1.1.0)
sysInfo=${sysInfo#"iso.3.6.1.2.1.1.1.0 = STRING: "}

echo -e "\tsysInfo: $sysInfo" >> $OUTPUT
echo -e "\tsysName: $($GET $host .1.3.6.1.2.1.1.5.0 | cut -d ' ' -f 4-)" >> $OUTPUT
echo -e "\tsysLocation: $($GET $host .1.3.6.1.2.1.1.6.0 | cut -d ' ' -f 4-)" >> $OUTPUT
echo "" >> $OUTPUT
echo -e "\tPILHA" >> $OUTPUT

entity+=($($WALK $host 1.3.6.1.2.1.47.1.1.1.1.5 | grep "= INTEGER: 3" | cut -d '.' -f 13 | awk '{print $1}'))
count=1
for i in "${entity[@]}"; do
	echo -e "\t$count - $($GET $host 1.3.6.1.2.1.47.1.1.1.1.2.$i | cut -d ' ' -f 4-)" >> $OUTPUT
	((count++))
done
echo "" >> $OUTPUT
echo "Done polling $host SysInfo!"
### END BASE INFO ###


### IPv4 ADDRESSES ###
echo "Polling $host IP addresses"

echo -e "\tIPv4" >> $OUTPUT

ipv4Adds+=($($WALK $host 1.3.6.1.2.1.4.20.1.1 | cut -d ' ' -f 4-))
echo -e "\tADD\t\t\tMASCARA\t\tINTERFACE" >> $OUTPUT
for i in "${ipv4Adds[@]}"; do
	CIDR=$(echo -e "$($GET $host 1.3.6.1.2.1.4.20.1.3.$i | cut -d ' ' -f 4)" | awk '
		function count1s(N){
			c = 0
			for(i=0; i<8; ++i) if(and(2**i, N)) ++c
		return c
		}
		function subnetmaskToPrefix(subnetmask) {
			split(subnetmask, v, ".")
		return count1s(v[1]) + count1s(v[2]) + count1s(v[3]) + count1s(v[4])
		}
		{
			print("/" subnetmaskToPrefix($1))
		}')
	# The function above was written by Jose Ricardo Bustos M.
	# It can be found at stackoverflow: https://stackoverflow.com/questions/40807781/awk-converting-subnet-mask-to-prefix
	echo -e "\t$i\t\t$CIDR\t\t$($GET $host .1.3.6.1.2.1.2.2.1.2.$($GET $host 1.3.6.1.2.1.4.20.1.2.$i | cut -d ' ' -f 4) | cut -d ' ' -f 4)" >> $OUTPUT
done

echo "" >> $OUTPUT

echo "Done polling $host IP Addresses!"
### END IPv4 ADDRESSES


### IPv4 ROUTES ###

	# Code has been removed. Its was deemed irrelevant.

### END IPv4 ROUTES ###


### INTERFACES ###
echo -e "\tINTERFACES" >> $OUTPUT
echo "" >> $OUTPUT
echo -e "\tINDEX\tDESCRIPTION\t\tALIAS\tTYPE\tMTU\tSPEED\tPHYS ADD\tADM STATUS\tOPERATIONAL STATUS" >> $OUTPUT
echo "" >> $OUTPUT

ifIndex+=($($WALK $host .1.3.6.1.2.1.2.2.1.1 | cut -d ' ' -f 4-))

	for i in "${ifIndex[@]}"; do
		ifDesc=$($GET $host .1.3.6.1.2.1.2.2.1.2.$i | cut -d ' ' -f 4-)
		ifAlias=$($GET $host .1.3.6.1.2.1.31.1.1.1.18.$i | cut -d ' ' -f 4-)
		ifType=$($GET $host .1.3.6.1.2.1.2.2.1.3.$i | cut -d ' ' -f 4-)
		# Lazy.
		case $ifType in
		117)
			ifType="gigabitEthernet"
		;;
		*)
		;;
		esac
		ifMTU=$($GET $host .1.3.6.1.2.1.2.2.1.4.$i | cut -d ' ' -f 4-)
		ifSpeed=$($GET $host .1.3.6.1.2.1.2.2.1.5.$i | cut -d ' ' -f 4-)
		ifPhysAddress=$($GET $host .1.3.6.1.2.1.2.2.1.6.$i | cut -d ' ' -f 4-)
		ifAdminStatus=$($GET $host .1.3.6.1.2.1.2.2.1.7.$i | cut -d ' ' -f 4-)
		ifOperStatus=$($GET $host .1.3.6.1.2.1.2.2.1.8.$i | cut -d ' ' -f 4-)

		echo -e "\t$i\t$ifDesc\t$ifAlias\t$ifType\t$ifMTU\t$ifSpeed bps\t$ifPhysAddress\t$ifAdminStatus\t$ifOperStatus" >> $OUTPUT
	done
echo "" >> $OUTPUT
### END INTERFACES ###


### VLANS ###

	# Code has been removed. Many devices didn't had the MIB used.

### END VLANS ###


### LLDP ###
echo "Polling $host LLDP Table"
echo -e "\tLLDP" >> $OUTPUT
echo "" >> $OUTPUT

lldpInterval=$($GET $host .1.0.8802.1.1.2.1.1.1.0 | cut -d ' ' -f 4-)
lldpTTL=$(( $($GET $host .1.0.8802.1.1.2.1.1.2.0 | cut -d ' ' -f 4-) * $lldpInterval ))
#lldpLastModify=$($GET $host .1.0.8802.1.1.2.1.2.1.0 | cut -d ' ' -f 4-)
lldpChassis=$($GET $host .1.0.8802.1.1.2.1.3.2.0 | cut -d ' ' -f 4-)
lldpChassisType=$($GET $host .1.0.8802.1.1.2.1.3.1.0 | cut -d ' ' -f 4-)

		case $lldpChassisType in
		1)
			lldpChassisType="entPhysicalAlias for chassis"
		;;
		2)
			lldpChassisType="ifAlias for an interface"
		;;
		3)
			lldpChassisType="entPhysicalAlias for port or backplane"
		;;
		4)
			lldpChassisType="MAC address for the system"
		;;
		5)
			lldpChassisType="A management address for the system"
		;;
		6)
			lldpChassisType="interfaceName"
		;;
		7)
			lldpChassisType="local"
		;;
		*)
		;;
		esac

lldpSysName=$($GET $host .1.0.8802.1.1.2.1.3.3.0 | cut -d ' ' -f 4-)
echo -e "\tLLDP SYS NAME: $lldpSysName" >> $OUTPUT
echo -e "\tLLDP CHASSIS: $lldpChassis\t\tSUBTYPE: $lldpChassisType" >> $OUTPUT
echo -e "\tLLDP INTERVAL: $lldpInterval" >> $OUTPUT
echo -e "\tLLDP TTL: $lldpTTL" >> $OUTPUT
echo "" >> $OUTPUT

lldpInterval=''
lldpTTL=''
lldpChassis=''
lldpChassisType=''

lldpLocalPortIndex+=($($WALK $host 1.0.8802.1.1.2.1.3.7.1.2 | cut -d '.' -f 12 | awk '{print $1}'))

echo -e "\tINDEX\tPORT ID SUBTYPE\tIF DESCR\tREMOTE PORT\tREMOTE ADDRESS\tREMOTE SYS NAME\tREMOTE CHASSIS" >> $OUTPUT
echo "" >> $OUTPUT

for i in "${lldpLocalPortIndex[@]}"; do
	lldpLocalSubType=$($GET $host .1.0.8802.1.1.2.1.3.7.1.2.$i | cut -d ' ' -f 4-)
	case $lldpLocalSubType in
		1)
			lldpLocalSubType="interfaceAlias"
		;;
		2)
			lldpLocalSubType="portComponent"
		;;
		3)
			lldpLocalSubType="macAddress"
		;;
		4)
			lldpLocalSubType="networkAddress"
		;;
		5)
			lldpLocalSubType="interfaceName"
		;;
		6)
			lldpLocalSubType="agentCircuitId"
		;;
		7)
			lldpLocalSubType="local"
		;;
		*)
			lldpLocalSubType="Unknown"
		;;
		esac

	lldpLocalDescr=$($GET $host .1.0.8802.1.1.2.1.3.7.1.3.$i | cut -d ' ' -f 4-)
	timeMark=$($WALK $host .1.0.8802.1.1.2.1.4.1.1.7 | grep -E "iso\.0\.8802\.1\.1\.2\.1\.4\.1\.1\.7\.[0-9]{,100}\.$i\." | cut -d '.' -f 12 | tail -1)
	if [[ $timeMark = '' ]]
	then
		timeMark=''
		lldpLocalSubType=''
		lldpLocalDescr=''
		lldpRemotePort=''
		lldpRemoteAddress=''
		lldpRemoteSysName=''
		lldpRemoteChassis=''
		continue
	fi

	lldpRemotePort=$($WALK $host .1.0.8802.1.1.2.1.4.1.1.7.$timeMark.$i | cut -d ' ' -f 4- | tail -1)
	lldpRemoteAddress=$($WALK $host .1.0.8802.1.1.2.1.4.2.1.4.$timeMark.$i | cut -d '.' -f 17-20 | awk '{print $1}'| tail -1)
	lldpRemoteSysName=$($WALK $host .1.0.8802.1.1.2.1.4.1.1.9.$timeMark.$i | cut -d ' ' -f 4- | tail -1)
	lldpRemoteChassis=$($WALK $host 1.0.8802.1.1.2.1.4.1.1.5.$timeMark.$i | cut -d ' ' -f 4- | tail -1)
	echo -e "\t$i\t$lldpLocalSubType\t$lldpLocalDescr\t$lldpRemotePort\t$lldpRemoteAddress\t$lldpRemoteSysName\t$lldpRemoteChassis" >> $OUTPUT

	timeMark=''
	lldpLocalSubType=''
	lldpLocalDescr=''
	lldpRemotePort=''
	lldpRemoteAddress=''
	lldpRemoteSysName=''
	lldpRemoteChassis=''
done
echo "" >> $OUTPUT
echo "Done Polling $host LLDP Table"
### END LLDP ###


### END MAIN ###
