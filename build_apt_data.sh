#! /bin/bash

build_apt_data_logs() {
	pushd "$DATA_DIR" 1> /dev/null
	rm -f log.*.log 2> /dev/null

	#save full logs
	fakeroot -u dpkg --get-selections > log.dpkg.get-selections.log
	fakeroot -u dpkg-query --show > log.dpkg-query.show.log
	fakeroot -u cat /var/log/installer/initial-status.gz | gzip -d > log.initial-status.log
	fakeroot -u ls "$CACHE_DIR"/*.deb 2> /dev/null  | xargs -n1 basename 2> /dev/null > log.cached.log
	fakeroot -u ls "$REPO_DIR"/*.deb 2> /dev/null  | xargs -n1 basename 2> /dev/null > log.local.log
	popd 1> /dev/null
}

build_apt_data_packages() {
	pushd "$DATA_DIR" 1> /dev/null
	local app_option="$1"      #Ex: only, cached
	local app_values="${*:2}"       #Ex: apache2 linux-generic
	
	if is_data_cached "$app_option"; then
		popd 1> /dev/null
		return $(false)
	fi

	case $app_option in
	"current" )
		# packages.current.list: all packages currently installed in the system 
		fakeroot -u dpkg-query --show -f '${Package} ${Status}\n' | grep "install ok installed" | cut -d ' ' -f 1 | sort | uniq > packages.current.list
	;;

	"removed" )
		# packages.removed.list: all packages uinstalled from the system
		fakeroot -u dpkg-query --show -f '${Package} ${Status}\n' | grep "deinstall ok" | cut -d ' ' -f 1 | sort | uniq > packages.removed.list
	;;
	
	"default" )
		# packages.default.list: default packages that came with initial installation
		fakeroot -u cat /var/log/installer/initial-status.gz | gzip -d | grep '^Package:' | awk '{print $2}' | sort | uniq > packages.default.list
	;;
	
	"cached" )
		# packages.cached.list: all packages cached
		fakeroot -u ls "$CACHE_DIR"/*.deb 2> /dev/null | xargs -n1 basename | grep -oP '^[^_]*(?=_)' | sort | uniq > packages.cached.list
	;;
	
	"auto" )
		# packages.auto.list: packages automatically installed
		fakeroot -u apt-mark showauto | sort | uniq > packages.auto.list
	;;
	
	"manual" )
	# packages.manual.list: packages automatically installed
		fakeroot -u apt-mark showmanual | sort | uniq > packages.manual.list
		#sort files and remove duplicate lines
		for file in $(ls packages.*.list); do
			sort $file | uniq > tmp.list;
			mv tmp.list $file;
		done
	;;
	
	"explicit" )
		app build-apt-data default
		app build-apt-data current
		# packages.explicit.list: only packages installed after default installation
		comm -31 packages.default.list packages.current.list | sort | uniq > packages.explicit.list
	;;

	"local" )
		#packages already installed in our local repository build by the command
		#fakeroot -u ls "$REPO_DIR"/*.deb 2> /dev/null | xargs -n1 basename 2> /dev/null | grep -oP '^[^_]*(?=_)' | sort | uniq > packages.local.list
		fakeroot -u ls "$REPO_DIR"/*.deb 2> /dev/null | xargs -n1 basename 2> /dev/null | grep -oP '^[^_]*(?=_)' | sed 's/'"$VERSION_SUFFIX"'//g' | sort | uniq > packages.local.list
	;;

	"manifest" )
		#wget -qO - http://releases.ubuntu.com/raring/ubuntu-13.04-desktop-i386.manifest > raring.manifest
		cat raring.manifest | grep -oP '^[^:]+' | cut -f1 |  sort | uniq > packages.manifest.list
	;;

	"repack" )
		# packages available for repacking
		# repack = current - local - cached
		app build-apt-data current
		app build-apt-data local
		app build-apt-data cached
		comm -32 packages.current.list <(cat packages.local.list packages.cached.list | sort | uniq) | sort | uniq > packages.repack.list
	;;

	"only" )
		#build list for specific packages. Usage: app build-repository linux-generic language-pack-en 
		[[ ! -z "$app_values" ]] && echo "$app_values" | tr ',' " " | tr ' ' "\n" | sort | uniq > "$DATA_DIR/packages.only.list"
	;;


	"available" )
		#fakeroot -u dpkg -l "*" 2> /dev/null | grep -vP "^(Desired=|\||\+)"|  cut -d " " -f3 |  sort | uniq > packages.available.list
		#packages available in all the repositories (installed and uninstalled)
		fakeroot -u apt-cache pkgnames 2> /dev/null | sort | uniq > packages.available.list
	;;

	"*" )
		echo "Error. Unknown option: \"$*\"" 1>&2
	;;
	esac

	#list how many packages
	[[ "$ORIGINAL_ARG_1" == "build-apt-data" ]] && echo $(wc -l packages."$app_option".list | grep -oP "s*([0-9]+)\s+") packages built.
	popd 1> /dev/null
}
