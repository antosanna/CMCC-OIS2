#!/bin/sh -l
set +evxu
. ~/.bashrc
. $DIR_UTIL_OIS2/descr_OIS2.sh
if [[ $machine == "juno" ]]; then	
condafunction() {
   local comm=$1
   local env=$2	
   . ~/load_conda
   if [  $comm == "activate"  ]; then
      	conda $comm $env
   elif [  $comm == "deactivate"  ]; then
      	conda $comm
   fi
}
elif [[ $machine == "cassandra" ]] ; then
condafunction() {
   local comm=$1
   local env=$2 
    if [[ $env != "$envcondacm3" ]]
    then
        .  ~/load_miniconda
    else 
         . ~/load_conda
    fi
    if [[  $comm == "activate"  ]]; then
         conda $comm $env
    elif [[  $comm == "deactivate"  ]]; then
         conda $comm
    fi
}
fi
