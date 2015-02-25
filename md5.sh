#! /bin/bash
#
# md5compare
# A graphical MD5 validator
# http://jimcooncat.wordpress.com/2011/03/09/a-graphical-md5-validator/
# Released under MIT license
# http://www.opensource.org/licenses/mit-license.html
#
# Usage: md5compare [filename]
# Can accept a filename for an argument, for
# example to use with a file manager's "Open with" feature,
# or will show a file selector if none is given.
#
Commandname=$(basename $0)
SupposedMD5=$(zenity --entry \
  --text "Enter MD5Sum that file is supposed to be" \
  --title $Commandname)
if [ $# -gt 0 ]; then
  Filename="$1"
else
  Filename=$(zenity --file-selection  --title $Commandname)
fi
Tempfile=$(tempfile --prefix="md5-" --suffix=".list")
SpaceChar=" "
echo "$SupposedMD5$SpaceChar$SpaceChar$Filename" > $Tempfile
Result=$(md5sum -c $Tempfile 2>&1 | \
  tee >(zenity --progress --text "Calculating MD5sum" \
    --title $Commandname --pulsate --auto-close) )
rm $Tempfile
zenity --info --text "$SupposedMD5\n $Result " --title $Commandname