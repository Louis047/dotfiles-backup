#!/bin/sh
sed -i \
         -e 's/#fafafa/rgb(0%,0%,0%)/g' \
         -e 's/#000000/rgb(100%,100%,100%)/g' \
    -e 's/#0f0f0f/rgb(50%,0%,0%)/g' \
     -e 's/#5c5c5c/rgb(0%,50%,0%)/g' \
     -e 's/#ededed/rgb(50%,0%,50%)/g' \
     -e 's/#0b0b0b/rgb(0%,0%,50%)/g' \
	"$@"
