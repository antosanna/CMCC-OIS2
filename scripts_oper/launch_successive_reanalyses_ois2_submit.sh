#!/bin/sh -l
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
set -euvx
$OIS2_scripts/reanalyses_ois2_submit.sh
