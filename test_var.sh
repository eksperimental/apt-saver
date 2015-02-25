#! /bin/bash
SOME_DIR="~/some/dir"
OTHER_DIR="~/other/dir"
AND_ANOTHER_DIR="~/and/another/dir"
for var in "SOME_DIR" "OTHER_DIR" "AND_ANOTHER_DIR"; do
	eval $var="${!var/"~"/$HOME}"
done

echo "$SOME_DIR"
echo "$OTHER_DIR"
echo "$AND_ANOTHER_DIR"

/home/username/some/dir
/home/username/other/dir
/home/username/and/another/dir
