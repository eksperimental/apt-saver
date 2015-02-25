#! /bin/bash
. /etc/lsb-release

ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
#DISTRIB_ID=Ubuntu
#DISTRIB_RELEASE=13.04
#DISTRIB_CODENAME=raring
#DISTRIB_DESCRIPTION="Ubuntu 13.04"

case $(uname -m) in
	x86_64)
	    BITS=64
	    ;;
	i*86)
	    BITS=32
	    ;;
	*)
	    BITS=?
	    ;;
esac

MANIFEST_URL = "http://releases.ubuntu.com/"$DISTRIB_CODENAME"/"$DISTRIB_ID"-"$DISTRIB_RELEASE"-desktop-i386.manifest" $DISTRIB_CODENAME".manifest"
MANIFEST_URL = "$(echo $MANIFEST_URL | tr '[:upper:]' '[:lower:]' )"

#find the right version at http://releases.ubuntu.com/($DISTRIB_CODENAME)/
wget -qO - $MANIFEST_URL

echo $OS
echo $ARCH
echo $VER