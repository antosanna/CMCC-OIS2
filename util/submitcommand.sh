#!/bin/sh -l
#         command+=' -app $S_apprun'
#not defined yet
. ~/.bashrc
. ${DIR_UTIL_OIS2}/descr_OIS2.sh
set -eu
usage() { echo "Usage: $0 [-m <machine string >] [-q <queue string>] [-s <scriptname string >] [-j <jobname string >] [-d <scriptdir string >] [-l <logdir string >] [-i <input string OPTIONAL>] [-R <cores in the same node OPTIONAL BUT REQUIRES ntask>] [-f <is this the model? OPTIONAL>] [-J <previousjobID number OPTIONAL>] [-p <previousjob string OPTIONAL>] [-w <second previousjob string OPTIONAL>] [-e <previousjobi-exited string OPTIONAL>] [-f <previousjob-exited string OPTIONAL>] [-Z <no arg string OPTIONAL>] [-M <memory integer OPTIONAL >] [-P <partition string OPTIONAL>] [-r <reservation string OPTIONAL>] [-n <ntask string OPTIONAL>] [-t <duration string OPTIONAL>] [-S <qos quality of service string OPTIONAL>] [-E <string to require exlusivity of nodesOPTIONAL >] [-N <number of nodes OPTIONAL>][-B <starting-time string OPTIONAL (format yyyy:mm:dd:hh:mm)>]" 1>&2; exit 1; }

if [[ $# -eq 0 ]]
then
   usage
fi
# Initialize arguments
# Reason: in the SPS3 version of this script, the arguments are empty string, and "test -z" command is used. This prevents the use of "set -u" option.
starttime="None"
#machine="None"
queue="None"
isthemodel="None"
coreinnode="None"
scriptname="None"
jobname="None"
input="None"
logdir="None"
scriptdir="None"
exited="None"
exited2="None"
prevID="None"
prev="None"
prev2="None"
prev3="None"
memdefault=1000
mem=$memdefault
partition="None"
reservation="None"
qos="None"
exclusive="None"
ntask="None"
localtime="None"
basic="None"
nodes="None"

while getopts ":m:M:q:Q:f:P:r:R:n:N:s:t:J:j:i:l:d:e:f:p:w:W:Z:B:S:E:" o; do
    case "${o}" in
        S)
            qos=${OPTARG}
            ;;
        E)
            exclusive=${OPTARG}
            ;;
        B)
            starttime=${OPTARG}
            ;;
        m)
            machine=${OPTARG}
            ;;
        q)
            queue=${OPTARG}   
            ;;
        N)
            nodes=${OPTARG}   
            ;;
        f)
            isthemodel=${OPTARG}
            ;;
        R)
            coreinnode=${OPTARG}
            ;;
        s)
            scriptname=${OPTARG}
            ;;
        j)
            jobname=${OPTARG}
            ;;
        i)
            input=${OPTARG}
            ;;
        l)
            logdir=${OPTARG}
            ;;
        d)
            scriptdir=${OPTARG}
            ;;
        p)
            prev=${OPTARG}
            ;;
        J)
            prevID=${OPTARG}
            ;;
        e)
            exited=${OPTARG}
            ;;
        f)
            exited2=${OPTARG}
            ;;
        w)
            prev2=${OPTARG}
            ;;
        W)
            prev3=${OPTARG}
            ;;
        M)
            mem=${OPTARG}
            ;;
        P)
            partition=${OPTARG}
            ;;
        r)
            reservation=${OPTARG}
            ;;
        n)
            ntask=${OPTARG}
            ;;
        t)
            localtime=${OPTARG}
            ;;
        Z)
            basic=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

if [[ "$machine" == "None" ]]
then
   echo "missing machine"
   usage
fi

if [[ "$basic" == "None" ]]
then
      if [[ "$scriptname" == "None" ]]
      then
         echo "missing scriptname"
         usage
      fi
      if [[ "$jobname" == "None" ]]
      then
         echo "missing jobname"
         usage
      fi
      if [[ "$logdir" == "None" ]]
      then
         echo "missing logdir"
         usage
      fi
      if [[ "$scriptdir" == "None" ]]
      then
         echo "missing scriptdir"
         usage
      fi
fi
   
if [[  "$machine" == "zeus" ]]
then
  # initalize command
  command='bsub '
  # if you require a number of cores in the same node
  if [[ "$coreinnode" != "None" ]]
  then
    # if you defined the required number of cores n
     if [[ "$ntask" != "None" ]]
     then
        command+=' -n $ntask -R "span[ptile=$coreinnode]"'
       # if  this is the model
        if [[ "$isthemodel" != "None" ]]
        then
           command+=' -x'
        fi
     else
        echo "-R activated but -n missing"
        usage
     fi
   fi
      
  # first of all add condition for -sla attach to service class [ SC_sp1 or SC_SERIAL_sp1]
#  if [[ `whoami` == $operational_user ]] || [[ `whoami` == "sp2" ]] || [[ `whoami` == "sps-dev" ]] #  second condition just for test purposes
#  then
    # queues on zeus
    #  serialq_l=s_long
    #  parallelq_s=p_short

    # queue condition 
   if [[ "$queue" == "None" ]] # if is not defined
   then
      # the only process without $queue is bsub of $case.run -> parallel, with the exception of postrun from st_archive.sh
      command+=' -P $pID '
      if [[ $scriptname == *"postrun"* ]]; then
         command+=' -sla ${sla_serialID} -app $S_apprun'
      # exception for ag_h process (CAM atmospheric IC condition) don't send over sla (since run 7 days before) 
#      elif [[ $scriptname == *"ag_h"* ]]; then
#      :
      fi

   else 
      # $queue is defined and contains string poe -> parallel
      command+=' -P $pID'
      if [[ "$queue" == *"p_"* ]]; then
         command+=' -sla $slaID -app $apprun'
      # $queue is defined and contains string serial -> serial        
      elif [[ "$queue" == *"s_"* ]]; then
         if [[ `whoami` == $operational_user ]]
         then
# TEMPORARY
            command+=' -sla ${sla_serialID} -app $S_apprun'
         fi
      fi
   fi


   if [[ "$basic" != "None" ]]
   then
      command+=' < '
      set -evx   
      command+=' '$scriptdir/$scriptname
      eval $command 
      exit 0
   else
      command+=" -rn -Ep '$DIR_UTIL_OIS2/Job_report_email.sh $mymail' -J $jobname -o $logdir/${jobname}_%J.out -e $logdir/${jobname}_%J.err"
      if [[ "$prevID" != "None" ]]
      then
         command+=' -ti -w "done($prev)"'
      fi
      if [[ "$prev" != "None" ]]
      then
         if [[ "$prev2" != "None" ]]
         then
            if [[ "$prev3" != "None" ]]
            then
               command+=' -ti -w "done('$prev') && done('$prev2') && done('$prev3')"'
            else
               command+=' -ti -w "done('$prev') && done('$prev2')"'
            fi
         else
            command+=' -ti -w "done('$prev')"'
         fi
      fi
      if [[ "$exited" != "None" ]] 
      then
         command+=' -ti -w "exit('$exited')"'
      fi
      if [[ "$exited" != "None" ]] && [[ "$exited2" != "None" ]]
      then
         command+=' -ti -w "exit('$exited') || exit('$exited2')"'
      fi
#      if [[ $mem -ne $memdefault ]]
#      then
# (mem is expressed in MB)
         command+=' -R "rusage[mem='$mem']"'
#      fi
   fi
   if [[ "$starttime" != "None" ]]
   then
     command+=' -b '"'$starttime'"''
   fi
   if [[ "$exclusive" != "None" ]]
   then
     command+=' -x '
   fi
   
   if [[ "$localtime" != "None" ]]
   then
# discriminate between serial and parallel
     queue_type=`bqueues -l $queue |grep QUEUE:|awk '{print $2}'|cut -c 1`
     if [[ $queue_type == "s" ]]
     then
# ACHTUNG!!! These limits are strictly dependent on sysmen settings!!!!
# RUNLIMIT s_medium 360min  s_short 30min
        if [[ $localtime -ge 1 ]] && [[ $localtime -le $time_limit_serialq_m ]]
        then
           queue=$serialq_m
        elif [[ $localtime -gt $time_limit_serialq_m ]]
        then
           queue=$serialq_l
           if [[ $localtime -gt $time_limit_serialq_m ]]
           then
              localtime=$time_limit_serialq_l
           fi
        fi
     elif [[ $queue_type == "p" ]]
     then
# RUNLIMIT p_medium 240min and p_short 120min
        if [[ $localtime -ge $time_limit_parallelq_s ]] && [[ $localtime -le $time_limit_parallelq_m ]]
        then
           queue=$parallelq_m
        elif [[ $localtime -gt $time_limit_parallelq_m ]]
        then
           queue=$parallelq_l
           if [[ $localtime -gt $time_limit_parallelq_l ]]
           then
              localtime=$time_limit_parallelq_l
           fi
        fi
     fi   
     command+=' -W '"'$localtime:00'"' -q $queue'
   else
     command+=' -q $queue'
   fi

   if [[ "$input" == "None" ]]
   then
     input=""
   fi

   set -evx   
   command+=' '$scriptdir/$scriptname
#   echo $command $input
   eval $command ${input}
   exit 0
fi 

if [[  "$machine" == "juno" ]] || [[ "$machine" == "cassandra" ]]
then
  # initalize command
  command='bsub '
  # if you require a number of cores in the same node
  if [[ "$coreinnode" != "None" ]]
  then
    # if you defined the required number of cores n
     if [[ "$ntask" != "None" ]]
     then
        command+=' -n $ntask -R "span[ptile=$coreinnode]"'
       # if  this is the model
        if [[ "$isthemodel" != "None" ]]
        then
           command+=' -x'
        fi
     else
        echo "-R activated but -n missing"
        usage
     fi
  fi
      

    # queue condition 
   if [[ "$queue" == "None" ]] # if is not defined
   then
      # the only process without $queue is bsub of $case.run -> parallel, with the exception of postrun from st_archive.sh
      command+=' -P $pID '
      if [[ $scriptname == *"postrun"* ]]; then
#not defined yet
#         command+=' -app $S_apprun'
         :
      fi

   else 
      # $queue is defined and contains string poe -> parallel
      command+=' -P $pID'
      if [[ "$queue" == *"p_"* ]]; then
         command+=' -sla $slaID -app $apprun'
      # $queue is defined and contains string serial -> serial        
      elif [[ "$queue" == *"s_"* ]]; then
         if [[ `whoami` == $operational_user ]]
         then
#not defined yet
            command+=' -sla $sla_serialID -app $S_apprun'
           
         fi
      fi
   fi


   if [[ "$basic" != "None" ]]
   then
      command+=' < '
      set -evx   
      command+=' '$scriptdir/$scriptname
      eval $command 
      exit 0
   else
      command+=" -rn -Ep '$DIR_UTIL_OIS2/Job_report_email.sh $mymail' -J $jobname -o $logdir/${jobname}_%J.out -e $logdir/${jobname}_%J.err"
      if [[ "$prev" != "None" ]]
      then
         if [[ "$prev2" != "None" ]]
         then
            if [[ "$prev3" != "None" ]]
            then
               command+=' -ti -w "done('$prev') && done('$prev2') && done('$prev3')"'
            else
               command+=' -ti -w "done('$prev') && done('$prev2')"'
            fi
         else
            command+=' -ti -w "done('$prev')"'
         fi
      fi
      if [[ "$exited" != "None" ]] 
      then
         command+=' -ti -w "exit('$exited')"'
      fi
      if [[ "$exited" != "None" ]] && [[ "$exited2" != "None" ]]
      then
         command+=' -ti -w "exit('$exited') || exit('$exited2')"'
      fi
#      if [[ $mem -ne $memdefault ]]
#      then
# (mem is expressed in MB)
         command+=' -R "rusage[mem='$mem']"'
#      fi
   fi
   if [[ "$starttime" != "None" ]]
   then
     command+=' -b '"'$starttime'"''
   fi
   if [[ "$exclusive" != "None" ]]
   then
     command+=' -x '
   fi
   
   if [[ "$localtime" != "None" ]]
   then
# discriminate between serial and parallel
     queue_type=`bqueues -l $queue |grep QUEUE:|awk '{print $2}'|cut -c 1`
     if [[ $queue_type == "s" ]]
     then
# ACHTUNG!!! These limits are strictly dependent on sysmen settings!!!!
# RUNLIMIT s_medium 360min  s_short 30min
        if [[ $localtime -ge 1 ]] && [[ $localtime -le $time_limit_serialq_m ]]
        then
           queue=$serialq_m
        elif [[ $localtime -gt $time_limit_serialq_m ]]
        then
           queue=$serialq_l
           if [[ $localtime -gt $time_limit_serialq_m ]]
           then
              localtime=$time_limit_serialq_l
           fi
        fi
     elif [[ $queue_type == "p" ]]
     then
# RUNLIMIT p_medium 240min and p_short 120min
        if [[ $localtime -ge $time_limit_parallelq_s ]] && [[ $localtime -le $time_limit_parallelq_m ]]
        then
           queue=$parallelq_m
        elif [[ $localtime -gt $time_limit_parallelq_m ]]
        then
           queue=$parallelq_l
           if [[ $localtime -gt $time_limit_parallelq_l ]]
           then
              localtime=$time_limit_parallelq_l
           fi
        fi
     fi   
     command+=' -W '"'$localtime:00'"' -q $queue'
   else
     command+=' -q $queue'
   fi
   if [[ "$nodes" != "None" ]]
   then
     ntot=$((72 * $nodes))
     command+=' -n $ntot'
   fi

   if [[ "$input" == "None" ]]
   then
     input=""
   fi

   set -evx   
   command+=' '$scriptdir/$scriptname
#   echo $command $input
   eval $command ${input}
   exit 0
fi 
#end definitions for Juno
#now marconi
if [[ "$machine" == "leonardo" ]]
then
  unset SLURM_MEM_PER_CPU
  set -vx
  command='sbatch '
# modified 20240618 to allow for recover_interrupted.sh to run!!! previously was NONE
#  command='sbatch --export=NONE'
#  command='sbatch --export=all'
  if [[ "$basic" == "None"  ]]
  then
    # sbatch CMCC_Copern20 with resrervation
    #command="sbatch --account=CMCC_Copern20 --partition=$queue --qos=qos_resv --reservation=s_met_cmcc --job-name=$jobname --out=$logdir/${jobname}_%J.out --err=$logdir/${jobname}_%J.err  --time=05:00:00 --mail-type=ALL --mail-user=$mymail"
    # If qos is defined, then add it serial
    # If reservation is defined, then add it serial
    if [[ "$reservation" != "None" ]]
    then
       if [[ "$queue" != "None" ]] # if is not defined
       then
          if [[ "$queue" == "$serialq_l" ]]
          then
             command+=" --reservation=$sla_serialID "
          else
             command+=" --reservation=$slaID "
          fi
       else
          command+=" --reservation=$reservation"
       fi
    fi
    # If exclusive is defined, then add it 
    if [[ "$exclusive" != "None" ]]
    then
      #command+=' --nodes=$exclusive --exclusive '
      command+=' --exclusive '
    fi
   # set time (default 6hr)
    if [[ "$localtime" != "None" ]]
    then
      command+=' --time=$localtime:00:00 '

    else
      command+=' --time=06:00:00 '
    fi

    if [[ "$account_name" == "CMCC_reforeca" ]]
    then
    # sbatch $account_name with reservation
#      command+=" --qos=qos_lowprio --account=$account_name  --partition=$queue --job-name=$jobname --out=$logdir/${jobname}_%J.out --err=$logdir/${jobname}_%J.err   --mail-type=FAIL --mail-user=$mymail"
       if [[ "$queue" == "lrd_all_serial" ]]
       then
           command+=" --account=$account_name  --partition=$queue --job-name=$jobname --out=$logdir/${jobname}_%J.out --err=$logdir/${jobname}_%J.err --mail-type=FAIL --mail-user=$mymail"
       else
           command+=" --qos=qos_lowprio --partition=dcgp_usr_prod --account=$account_name --job-name=$jobname --out=$logdir/${jobname}_%J.out --err=$logdir/${jobname}_%J.err   --mail-type=FAIL --mail-user=$mymail"
       fi
    else
      command="sbatch --account=$account_name --partition=$queue --job-name=$jobname --out=$logdir/${jobname}_%J.out --err=$logdir/${jobname}_%J.err  --time=03:59:00 --mail-type=ALL --mail-user=$mymail"
    fi

    # (--nice decrease priority, positive value of nice decrease)
    # (usually regrid cam is 99767 but postrun 98000) now postrun is 154406
    # lt_archive_moredays --nice=10100
    # C3S (cam/clm) --nice=20100
    # checkers --nice=1000 
    # postrun 
    #
    # if [[  "$niceval" != "None" ]]
    # then
    #    command+=' --nice=$niceval '
    # fi

      if [[ "$prev" != "None" ]]
      then
        if [[ "$prev" =~ [a-zA-Z] ]]
        then  #to be sure that the dependency get the ID and not the jobname
           jobid1=$(squeue --noheader --format %i --name $prev )
           echo "sono stato  qua..."
        else
           jobid1=$prev 
        fi
           
        if [[ "$prev2" != "None" ]]
        then
              jobid2=$(squeue --noheader --format %i --name $prev2 )
              command+=' --dependency=afterok:$jobid1:$jobid2 '
        else
              command+=' --dependency=afterok:$jobid1 '
        fi
      fi
      if [[ "$exited" != "None" ]]
      then
         jid1=$(squeue --noheader --format %i --name $exited )
         if [[ "$exited2" != "None" ]]
         then
              jid2=$(squeue --noheader --format %i --name $exited2 )
              command+=' --dependency=afternotok:$jid1:$jid2 '
         else
              command+=' --dependency=afternotok:$jid1 '
         fi
      fi
#      if [[ $mem -ne $memdefault ]]
#      then
      # (mem is expressed directly)
        command+=' --mem=$mem '
#      fi
      if [[ "$ntask" != "None" ]]
      then
             command+=' --ntasks=$ntask '
      else
             command+=' --ntasks=1 '
      fi

  fi
  if [[ "$input" == "None" ]]
  then
    input=""
  fi
  command+=' '$scriptdir/$scriptname
  set -evx
#  echo $command $input
  eval $command ${input}
  exit 0
  set +evx   
fi
