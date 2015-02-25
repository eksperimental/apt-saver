#! /bin/bash

decode_version() {
	local file=$1
	#decode chars
	local version=$( echo $file {| sed -e's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\\\\x\1/g' || echo ''} | xargs echo -e )
	echo version
}

get_version() {
	local file=$1
	local file_decoded=$( decode_version $file )
	local version=$( echo $file_decoded {| grep -oP '([^_])+(?=_)' || echo '' } | paste -s -d '\t' | cut -f2 )
	echo version
}

get_version_installed() {
	local package_name="$0"
	version_installed=$(dpkg -s "$package_name" | grep -oP "(?<=Version:\s).*" )
}
get_file_installed() {
	local packages="${*}"
	echo $(apt-cache show --no-all-versions "$packages" |& grep -v "E: No package found" | grep -oP "(?<=Filename:\s).*" | xargs -n1 basename)
}
get_files_installed() {
	local file_list="$1"
	printf %s "$(apt-cache show --no-all-versions $(< "$file_list")  |& grep -v "E: No package found" | grep -oP "(?<=Filename:\s).*" | xargs -n1 basename 2> /dev/null)"
}
get_size_files_installed() {
	local file_list="$1"
	local sizes=$(apt-cache show --no-all-versions $(< "$file_list") |& grep -v "E: No package found" | grep -oP "(?<=Size:\s).*" | tr -d " \t")
	local l s=0
	for l in $sizes; do
		s=$((s+$l))
	done
	if [[ "$s" != "0" ]]; then
		human_filesize "$s"
	else
		false
	fi
}

get_files_local() {
	printf %s "$(fakeroot -u ls "$REPO_DIR"/*.deb 2> /dev/null | xargs -n1 basename 2> /dev/null | sort | uniq)"
}

get_list_local() {
	local file_list="$1"
	[[ ! -f "$1" ]] && echo "Please provide valid a file list: $file_list" 1>&2 && exit 1
	[[ ! -s "$1" ]] && echo '' && return $(true)
	printf %s "$(cat "$file_list" | grep -oP '^[^_]*(?=_)' | sort | uniq)"
}

more_info() {
	echo "Try '$APP_CMD help' for more information."
}

error_msg() {
	printf "$APP_CMD: Error! "
}

confirm () {
    # call with a prompt string or use a default
    read -r -p "${1:-Please confirm [Y/n]?} " response
	[[ -z "$response" && ! -z "$2" ]] && response="$2"
    case $response in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
	        false
            ;;
    esac
}

_check_BUILD_REPOSITORY_OPTIONS() {
	local app_option=$1
	#check for available options
	if ! echo "$BUILD_REPOSITORY_OPTIONS" | grep -qw "$app_option"; then
		error_msg 1>&2
		[[ -z  "$app_option" ]] && echo "Please choose what would you like to build." 1>&2
		printf 'Options available for "%s" are: %s\n' "$app_action" "${BUILD_REPOSITORY_OPTIONS// /, }" 1>&2
		echo "Example: '$APP_CMD $app_action current'" 1>&2
		more_info 1>&2
		return $(false)
	else
		return $(true)
	fi
}

capture_dpkg_repack_dir() {
	unset DPKG_REPACK_DIR
	local data
	if [ ! -t 0 ]; then
		read -r data
	else
		data="$*"
	fi
	regex="^dpkg-repack: dpkg-repack: created \.\/(.*) for "
	#regex="^dpkg-repack: (.*) for "
	if [[ $data =~ $regex ]]; then
		DPKG_REPACK_DIR="${BASH_REMATCH[1]}"
	fi
	echo "$data" | sed 's/dpkg-repack: created \.\/dpkg-repack-[0-9]* for //g'
}

capture_dpkg_deb_package() {
	unset DPKG_DEB_PACKAGE
	local data
	if [ ! -t 0 ]; then
		read -r data
	else
		data="$*"
	fi
	regex="^dpkg-deb: building package .* in \`\.\/(.*)'.$"
	if [[ $data =~ $regex ]]; then
		DPKG_DEB_PACKAGE="${BASH_REMATCH[1]}"
	fi
	echo "$data"
}


repack_files() {
	if [[ ${1:0:1} == "/" ]]; then
    	local file_list="$1"
	else
		#parse any multi line or space separated list
		local file_list=$(mktemp /tmp/output.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }
		echo "$*" | tr " " "\n" | tr -d "\t" | grep -vP "^$"  > $file_list
	fi

	[[ ! -f "$file_list" ]] && echo "Please provide valid a file list: $file_list" 1>&2 && exit 1
	[[ ! -s "$file_list" ]] && echo '' && return $(true)
	pushd "$REPO_DIR" 1> /dev/null

	local version_regex="Version: ([^[:space:]]*)"
	local package_name
	while IFS= read -r package_name || [[ $package_name ]]; do
		fakeroot -u dpkg-repack --generate "$package_name" 2>&1 | filter_dpkg | capture_dpkg_repack_dir > >(tee -a "$LOG_STD")
		if [[ ! -z "$DPKG_REPACK_DIR" ]]; then
			file="$REPO_DIR/$DPKG_REPACK_DIR/DEBIAN/control"
			sed -i 's/^Version: .*$/\0+'"$VERSION_SUFFIX"'/g' "$file"
			dpkg --build "$REPO_DIR/$DPKG_REPACK_DIR" "."  2>&1 | filter_dpkg | capture_dpkg_deb_package > >(grep -vP "^dpkg-deb: building package " | tee -a "$LOG_STD") && {
				DEB_PACKAGE_ORIGINAL=$(echo "$DPKG_DEB_PACKAGE" | sed 's/\+'"$VERSION_SUFFIX"'//g')
				[[ ! -z "$DPKG_DEB_PACKAGE" && ! -z $DEB_PACKAGE_ORIGINAL ]] && \
					mv "$REPO_DIR/$DPKG_DEB_PACKAGE" "$REPO_DIR/$DEB_PACKAGE_ORIGINAL"
				[[ ! -z "$DPKG_REPACK_DIR" ]] && \
					rm -fr "$REPO_DIR/$DPKG_REPACK_DIR"
			}
		fi
	done < "$file_list"

	[[ ! -z "$file_list" ]] && \
		rm -f "$DATA_DIR/$file_list" 2> /dev/null
	#clean last dir created
	fakeroot -u rm -rf "$REPO_DIR"/dpkg-repack-* 2> /dev/null
	
	#cat "$LOG_STD"
	#rm -f ."$LOG_STD" 2> /dev/null
	popd 1> /dev/null
	return 0
}

function filter_dpkg(){
	grep -v "contains user-defined field" | \
	grep -vP "^dpkg-deb: warning: ignoring [0-9]+ warning(s)? about the control file" | \
	grep -vP "^\s*$" | \
	#grep -vP "^dpkg-deb: building package " | \
	grep -v "Use dpkg --info (= dpkg-deb --info) to examine archive files," | \
	grep -v "and dpkg --contents (= dpkg-deb --contents) to list their contents."
}

human_filesize() {
	# courtesy of: http://www.commandlinefu.com/commands/view/9807/convert-number-of-bytes-to-human-readable-filesize
	awk -v sum="$1" 'BEGIN {
		hum[1024^3]="GB"; 
		hum[1024^2]="MB"; 
		hum[1024]="KB"
		if (sum==0) {
			print sum " KB"
		} else if (sum<1024) {
			n=sprintf("%.1f",sum/1024);
			if (n=="0.00") n="0.1"
			print n " KB"
		} else {	
			for (x=1024^3; x>=0; x/=1024) {
				if (sum>=x) {
					printf "%.2f %s\n",sum/x,hum[x];
					break;
				}
			}
		}
	} '
}

get_number_of_lines() {
	[[ ! -s "$1" ]] && echo 0
	echo $(wc -l "$1" 2> /dev/null | cut -f1 -d " ") || echo 0
}

is_data_cached() {
	local app_option=$1
	local data_file="$DATA_DIR"/packages."$app_option".list
	if [[ -f "$data_file" ]]; then
		local filemtime=$(stat -c %Y "$data_file")
		[[ "$filemtime" -ge "$EXECUTION_TIME" ]]
	else
		false
	fi
}

package_gz_needs_build() {
	#if there is no index, build it
	[[ ! -s "$REPO_DIR/Packages.gz" ]] && return $(true)
	
	local ctime_last_repo=$( printf "%.0f\n" $( find "$REPO_DIR"/*.deb -printf '%T@\n' | sort -r | head -1 ) )
	#ctime_last_repo=$( echo "($ctime_last_repo/10)*10" | bc )	

	# if there are no .deb files, then build it
	[[ "$ctime_last_repo" == '' ]] && return $(true)
	local ctime_packages_gz=$(stat -c %Z "$PACKAGES_GZ_FILE")

	#if the lastest .deb modified file is newer than the current index, then build it
	[[ "$ctime_last_repo" -ge "$ctime_packages_gz" ]] && return $(true)

	#if packages were created
	[[ -s installed.new.list ]] && return $(true)

	#other wise, we don't need to build it
	return $(false)
}

function contains_line() {
	local file="$1"
	local line=$(trim "$2")

	# return false if $line is empty OR $file is empty or doesn't exist
	[[ -z "$line" || ! -s "$file" ]] && return $(false)

	local l
	while IFS= read -r l || [[ $l ]]; do
		l=$(trim $l)
	    [[ "$l" == "$line" ]] && return $(true)
	done < "$file"
	return $(false)
}

trim() {
	[[ "$*" =~ [[:space:]]*([^[:space:]]|[^[:space:]].*[^[:space:]])[[:space:]]* ]]
	echo -n "${BASH_REMATCH[1]}"
}

generate_install_step_files() {
	pushd "$DATA_DIR" 1> /dev/null
	local step_number="$1"
	get_files_local > installed.step"$step_number".files
	get_list_local installed.step"$step_number".files > installed.step"$step_number".list
	# which are the files that have not been installed yet
	comm -23 to_install.list installed.step"$step_number".list | tr -d " \t" | sort | uniq > to_install.step"$(($step_number+1))".list
	popd 1> /dev/null
}

#source: http://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
display_time() {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  [[ $D > 0 ]] && ( [[ $D > 1 ]] && printf '%d days ' $D || printf '%d day ' $D )
  [[ $H > 0 ]] && ( [[ $H > 1 ]] && printf '%d hours ' $H || printf '%d hour ' $H )
  [[ $M > 0 ]] && ( [[ $M > 1 ]] && printf '%d minutes ' $M || printf '%d minute ' $M )
  [[ $D > 0 || $H > 0 || $M > 0 ]] && printf 'and '
  ( [[ $S == 1 ]] && printf '%d second' $S || printf '%d seconds' $S )
}

#source: http://askubuntu.com/a/197532
update_repo() {
	sudo apt-get update -o Dir::Etc::sourcelist="sources.list.d/$1" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
}
