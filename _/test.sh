#! /bin/bash
VERSION_SUFFIX="aptsaverwSatelliteU305"
DPKG_DEB_PACKAGE="racket_5.3.1+dfsg1-1+aptsaverwSatelliteU305_i386.deb"
DEB_PACKAGE_ORIGINAL=$(echo "$DPKG_DEB_PACKAGE" | sed 's/\+'"$VERSION_SUFFIX"'//g')
echo $DEB_PACKAGE_ORIGINAL
exit

output() {
	echo "out out out"
	echo "something something something" 
	echo "ERROR ERROR ERROR" 1>&2
}

filter(){
	#echo 	"$*" | grep -v "something"
	while read -r data; do
		echo "$data" | grep -v "something"
	done
	#echo 	"$*" | grep -v "something"
}

filter() { grep -v something; }

#./test2.sh 2>&1 | filter
# filter 2>&1 | ./test2.sh

output 2>&1 | filter
#./test2.sh 2>&1 | filter
exit

echo '  1234567' |  grep -Ev "^  [[:digit:]]{7,8}"
echo '  1234567890' |  grep -Ev "^  [[:digit:]]{7,8}"

exit
set +m
shopt -s lastpipe

VALUE=1
filter() {
	unset VALUE
	local data
	if [ ! -t 0 ]; then
		read -r data
	else
		data="$*"
	fi
	regex="(value=)(.*)"
	if [[ $data =~ $regex ]]; then
		VALUE="${BASH_REMATCH[2]}"
	fi
	#echo $VALUE
	#echo $data
	echo "VALUE (inside function)=$VALUE"
}

filter
echo $VALUE

#filter "ERR: one two three value=123"
#echo $VALUE

echo "ERR: one two three value=123" | filter
echo $VALUE

#filter $(<test.txt)
#echo $VALUE

exit


( echo "ERR: one two three value=123" ) | filter
echo $VALUE
#filter
exit






filterx() {
	local data
	while read data; do
		#echo $data | grep -oP "(?<=value=)(.*)"

		regex="(value=)(.*)"
		if [[ $data =~ $regex ]]; then
			echo "$BASH_REMATCH"
			#echo "$BASH_REMATCH[0]"
			#echo "$BASH_REMATCH[1]"
			echo ${BASH_REMATCH[0]}
			echo ${BASH_REMATCH[1]}
			echo ${BASH_REMATCH[2]}
			echo ${BASH_REMATCH[3]}
			echo "$LINENO>> "${BASH_REMATCH[*]}
			#echo "$BASH_REMATCH[@]"
			#echo "$BASH_REMATCH[*]"
			echo "$LINENO>> "${#BASH_REMATCH[*]}
			echo "$LINENO>> "${#BASH_REMATCH[0]}
		fi
	done
}

exit
./test2.sh 3>&1 1>&2 2>&3 | grep -oP "(?<=value=)(.*)" 3>&1 1>&2 2>&3 2> stderr


exit


( ERROR=$( ./test2.sh 3>&1 1>&2 2>&3 | grep -oP "(?<=value=)(.*)" ) ) 3>&1 1>&2 2>&3 2> stderr

exit

exit

exit
( ERROR=$( ./test2.sh 3>&1 1>&2 2>&3 | grep -oP "(?<=value=)(.*)" ) ) 3>&1 1>&2 2>&3 2> stderr
echo $ERROR
exit

exec 3>&1
( ./test2.sh ) 1>&2 2>&3 3>&- | grep "value" 2> stderr
exec  3>&-
exit

 # { ./test2.sh &> log; } | grep -vP "uno"
.
#ERROR=$( ( ./test2.sh ) 2> grep "f" ) 2> stderr > stdout



 #ERROR=$( { ./useless.sh | sed s/Output/Useless/ > outfile; } 2>&1 )