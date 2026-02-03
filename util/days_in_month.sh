#!/bin/sh -l
# $1=mm $2=yyyy
cal $1 $2 | awk 'NF {DAYS = $NF}; END {print DAYS}'
