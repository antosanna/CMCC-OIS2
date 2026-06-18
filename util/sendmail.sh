#!/bin/sh -l
# load variables from descriptor
. $HOME/.bashrc
. ${DIR_UTIL_OIS2}/descr_OIS2.sh
usage() { echo "Usage: $0 [-m <machine string >] [-e <email string >] [-M <bodymessage string>] [-t <title string>] [-a <append file OPTIONAL>] [-c <cc string OPTIONAL>] [-b <bcc string OPTIONAL>] [-r <report string OPTIONAL>] [-s <startdate string OPTIONAL>] [-E <member number OPTIONAL]" 1>&2; exit 1; }

while getopts ":m:e:M:t:c:a:b:r:s:E:" o; do
    case "${o}" in
        m)
            machine=${OPTARG}
            ;;
        M)
            message=${OPTARG}
            ;;
        e)
            email=${OPTARG}
            ;;
        t)
            title=${OPTARG}
            ;;
        s)
            startdate=${OPTARG}
            ;;
        E)
            ensemble=${OPTARG}
            ;;
        c)
            cc=${OPTARG}
            ;;
        a)
            applist=${OPTARG}
            ;;
        b)
            bcc=${OPTARG}
            ;;
        r)
            report=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

# check if message exists
# ok, now check for special characters in message and remove them (retain only . _ - () \n \r)
# "\\\" means that we save character \ in order to retain \n
#set -vx
message=`echo $message | tr -dc "'[:alnum:](-:. /_)\\\\\\\\"`
# After new method with  echo -e "$message \n `date`", there is no need for ()substitution
# substitute () with \( \)
#message=`echo $message |  sed 's/(/\\\(/g' `
#message=`echo $message |  sed 's/)/\\\)/g' `
#message+=" `date`"

# check if machine exists
if [ -z $machine ]
then
   usage
fi

# check if email exists
if [ -z $email ]
then
   usage
fi

if [ ! -z $report ]
then
   if [ ! -z $startdate ]
   then
      outlog=${DIR_REP}/$startdate/REPORT_${machine}.${SPSSystem}_${startdate}
      if [ ! -z $ensemble ]
      then
         outlog=${DIR_REP}/$startdate/report_${machine}.${SPSSystem}_${startdate}_${ensemble}
      fi
      mkdir -p ${DIR_REP}/$startdate
#      message=${message//'\n'/<br>}
      echo "${message} `date`" >> ${outlog}.`date +%Y%m%d`.txt
      echo " " >> ${outlog}.`date +%Y%m%d`.txt
      if [ "$report" = "only" ]
      then
         exit
      fi
   fi
fi

if [[ "$machine" == "zeus" ]] || [[ $machine == "juno" ]] || [[ $machine == "cassandra" ]]
then
   if [ ! -z $bcc ]
   then
      b=" -b $bcc"
   else
      b=""
   fi
   if [ `ls $applist|wc -w` -ne 0 ]
   then
      for app in $applist
      do
         a+=" -a $app"
      done
   else
      a=""
   fi
   if [ ! -z $cc ]
   then
      c=" -c $cc"
   else
      c=""
   fi
   #set -evx 
   echo -e "$message \n `date`" | mail $a $b $c  -s "$title" $email  
    
   set +evx  
   exit 0
fi

if [  "$machine" = "leonardo" ]
then
  # MODIFY TITLE TO INCLUDE BACKUP INTO IT
  if [[ $title == *"CPS1"* ]]; then
    oldString="CPS1"
    newString="CPS1 - $machine BACKUP"
    title=$(echo "${title/$oldString/$newString}")
  else
    title+=" - $machine BACKUP"
  fi  

  #https://stackoverflow.com/questions/63319313/sendmail-sending-corrupted-unreadable-pdf-over-mail-sending-with-base64-encodin  - working sendmail example for single attachment
  message+="<br> `date`"
  ARG_EMAIL_TO="$email"
  ARG_EMAIL_FROM="sp1 <sp1@cmcc.it>"
  ARG_EMAIL_SUBJECT="$title"

  #echo "Mime-Version: 1.0"
  #echo "Content-Type: text/html; charset='utf-8'"
  # echo -e "$message" is the key to keep new line

  attaching_section=" " 
  if [ `ls $applist|wc -w` -ne 0 ]
  then
      for app in $applist
      do
         a="$app"
         attaching_section+=`echo -e "echo "---q1w2e3r4t5";\necho 'Content-Type: application; name=\"'$(basename $a)'\"';\necho 'Content-Transfer-Encoding: base64';\necho 'Content-Disposition: attachment; filename=\"'$(basename $a)'\"';\necho;\nbase64 < \"$a\";\necho;\n"`
      done
  else
      attaching_section= "echo"
  fi
  if [ ! -z $cc ]
  then
    ARG_EMAIL_CC="$cc"
    (
    echo "To: ${ARG_EMAIL_TO}"
    echo "From: ${ARG_EMAIL_FROM}"
    echo "Cc:  ${ARG_EMAIL_CC}"
    echo "Subject: ${ARG_EMAIL_SUBJECT}"
    echo "MIME-Version: 1.0"
    echo 'Content-Type: multipart/mixed; boundary="-q1w2e3r4t5"'
    echo
    echo '---q1w2e3r4t5'
    echo 'Content-Type: text/html; charset=utf-8'
    echo 'Content-Transfer-Encoding: 8bit'
    echo
    echo "$message" 
    echo
    eval $attaching_section
    ) | sendmail -t


  else
 
  (
    echo "To: ${ARG_EMAIL_TO}"
    echo "From: ${ARG_EMAIL_FROM}"
    echo "Subject: ${ARG_EMAIL_SUBJECT}"
    echo "MIME-Version: 1.0"
    echo 'Content-Type: multipart/mixed; boundary="-q1w2e3r4t5"'
    echo
    echo '---q1w2e3r4t5'
    echo 'Content-Type: text/html; charset=utf-8'
    echo 'Content-Transfer-Encoding: 8bit'
    echo
    echo "$message" 
    echo
    eval $attaching_section
  ) | sendmail -t 

  fi


  exit 0 
fi
