#!/bin/bash

###############
## Variables ##
###############

PATHTOHPACMD="/usr/sbin/hpacucli"
HPACMDSLOT="sudo ${PATHTOHPACMD} ctrl all show"
BBHTAG="hpraid"           
COLUMN=${BBHTAG}          
COLOR="red"
FINALCOLOR="green"
LOGFILES="${BBTMP}/hphwraid.log"

###################
## Pre-Run tests ##
###################

  if [ ! -e ${PATHTOHPACMD} ]; then
      echo -e "\n\r\t/!\ hpacucli binary is not present on your system. It should be in ${PATHTOHPACMD}.\n\r"
      exit 1
  fi

###############
## Functions ##
###############

function CheckTheResult {
   if [ ${1} = "OK" ]; then
      COLOR="green"
   else
      COLOR="red"
      FINALCOLOR="red"
   fi
}

function SendResult {
   COLOR=${FINALCOLOR}
   MSG=`cat ${LOGFILES}`
      # Send back the result to the Hobbit Server
      $BB $BBDISP "status ${MACHINE}.${COLUMN} ${COLOR} `date`

      ${MSG}
      "
}

##########
## Main ##
##########
cat /dev/null > ${LOGFILES}
while read CTRL; do
   set ${CTRL}
   SLOT=${CTRL}

   # Some vars must be defined in the main()
   HPACMDPHY="sudo ${PATHTOHPACMD} controller slot=${SLOT} physicaldrive all show status"
   HPACMDLOG="sudo ${PATHTOHPACMD} controller slot=${SLOT} logicaldrive all show status"

   # Reset of log file
   echo "<br /><u>Hardware view on SLOT ${SLOT}</u>" >> ${LOGFILES}
 
   # Launch the raid physical hardware test
   while read LINE; do 
      set $LINE
      echo $LINE >> ${LOGFILES}
      CheckTheResult `echo ${LINE} | awk '{ print $NF }'`
         done < <(${HPACMDPHY} | sed -e '/^$/d')

   # Launch the raid physical hardware test
   echo " " >> ${LOGFILES}
   echo "<u>View from the OS:</u>" >> ${LOGFILES}
   echo " " >> ${LOGFILES}
   while read LINE; do
      set $LINE
      echo $LINE >> ${LOGFILES}
      CheckTheResult `echo ${LINE} | awk '{ print $NF }'` 
         done < <(${HPACMDLOG} | sed -e '/^$/d')
         done < <(${HPACMDSLOT} | awk '{print $6}' | sed -e '/^$/d' |sort -n)
   echo " " >> ${LOGFILES}

# Time to send the result back to Hobbit
SendResult
 
# Happy End
exit 0
