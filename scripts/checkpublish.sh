#!/bin/bash

prod=$1
if [ "$prod" = "" ]; then
        script=$(basename $0)
        echo "Usage: ${script} <path to prod>"
        exit 1
fi
if [ ! -e "$prod" ]; then
        echo "ERROR: Directory does not exist: $prod!"
        exit 1
fi

# Get path to this scripts
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check publish flag and publish
p=`cat $DIR/../publish`
if [ "$p" = "1" ]; then
  echo "0" > $DIR/../publish
  $DIR/proddeploy.sh $(readlink -f $DIR/../../..) $prod
fi