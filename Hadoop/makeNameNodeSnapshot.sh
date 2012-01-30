#!/bin/bash 

# Copyright 2011, Nathan Milford
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Creates a snapshot of the Hadoop Namenode Metadata..
# * Only notifies you if there is a problem and outpouts a log.
# * Retires snapshots older than a week.
# * Put it in cron to run hourly.

nameNode=namenode.example.com
email="you@example.com"
tsNow=$(date "+%F-%H")
tsLast=$(date "+%F-%H" --date='1 hour ago')
workDir=/backup/hadoop/work
targetDir=/backup/hadoop/namenode
logDir=$targetDir/log
logFile=$logDir/backup.log
targetSpacePercent=$(/bin/df -h $targetDir | /bin/sed -n '3p' | /bin/awk '{ print $4 }' | sed 's/.\{1\}$//')
targetSpaceThresh=91
snapNow=$targetDir/namenode-$tsNow.zip
snapLast=$targetDir/namenode-$tsLast.zip
snapSizeThresh=3



function checkforLog () {

   if [ ! -d $logDir ]; then

      errSubject="[$(hostname -s)] NameNode Snapshot Error:  Cannot log backup. ($tsNow)"
      errMessage="NameNode Snapshot Error:\n\n\t$logDir doesn't exist"

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      exit 1
   fi

}

function checkforTarget () {

   if [ ! -d $targetDir ]; then

      errSubject="[$(hostname -s)] NameNode Snapshot Error:  Target directory is missing. ($tsNow)"
      errMessage="NameNode Snapshot Error:\n\n\t$targetDir is missing"

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      echo "$(date) Target directory ($targetDir) is missing." >> $logFile
      exit 1
   fi

}

function checkforWorkDir () {

   if [ ! -d $workDir ]; then

      errSubject="[$(hostname -s)] NameNode Snapshot Error:  Work directory is missing. ($tsNow)"
      errMessage="NameNode Snapshot Error:\n\n\t$workDir is missing"

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      echo "$(date) Work directory ($workDir) is missing." >> $logFile
      exit 1
   fi

}

function checkTargetSpace () {

   if [ $targetSpacePercent -ge $targetSpaceThresh ]; then

      errSubject="[$(hostname -s)] NameNode Snapshot Error:  Not enough free space on target. ($tsToday)"
      errMessage="NameNode Snapshot Error:\n\n\tFree Space on $targetDir is $targetSpacePercent%, threshold is $targetSpaceThresh%"

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      echo "$(date) Free Space on $targetDir is $targetSpacePercent%, threshold is $targetSpaceThresh%" >> $logFile
      exit 1
   fi

}


function checkIfSnapshotExists () {

   if [ -s $snapNow ]; then

      errSubject="[$(hostname -s)] NameNode Snapshot Error:  Snapshot already exists! ($tsToday)"
      errMessage="NameNode Snapshot Error:\n\n\tSnapshot script was halted because $(hostname -s):$snapNow already exists. Please investigate why and restart the snapshot manually."

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      exit 1
      echo "$(date) This hours' snapshot ($(hostname -s):$snapNow) exists, exiting! " >> $logFile
   fi

}

function checkForLastSnapshot () {

   if [ ! -s $snapLast ]; then

      errSubject="[$(hostname -s)] NameNode Snapshot Notice:  Previous hour's snapshot does not exist! ($tsToday)"
      errMessage="NameNode Snapshot Notice:\n\n\tThis is only informational, but $(hostname -s):$snapLast does not exist.\n\n\tToday's snapshot will continue to run but please investigate why the last ($tsLast) snapshot did not complete."

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      echo "$(date) Previous hour's snapshot ($(hostname -s):$snapLast) does not exist! " >> $logFile
   fi

}

function compareSnapshotSizes () {

   snapNowSize=$(stat -c%s $snapNow)
   snapLastSize=$(stat -c%s $snapLast)
   percentDiff=$(echo "scale=3; ( $snapNowSize - $snapLastSize  ) / $snapLastSize  * 100"  | /usr/bin/bc -l | /bin/sed 's/\-//g')

   if [ $(echo "$percentDiff > $snapSizeThresh" | /usr/bin/bc -l) -eq 1 ]; then

      errSubject="[$(hostname -s)] NameNode Snapshot Notice:  Percent change in snapshot size is too great! ($tsNow)"
      errMessage="NameNode Snapshot Notice:\n\n\tThis is only informational, but the size difference between $(hostname -s):$snapNow and $(hostname -s):$snapLast is greater than the current threshold of $snapSizeThresh%.\n\n\t\t$(hostname -s):$snapLast is $snapLastSize bytes.\n\t\t$(hostname -s):$snapToday is $snapTodaySize bytes.\n\n\tToday's snapshot script has completed, but please investigate the size discrepancy as it may be an indication of a bad snapshot."

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      echo "$(date) The size difference between $(hostname -s):$snapNow and $(hostname -s):$snapLast is greater than the current threshold of $snapSizeThresh%." >> $logFile
   fi

}

function retireOldSnapshots () {

   find $targetDir/namenode* -type f -mtime +7 -exec echo "$(date) retiring backup: " {}  \; >> $logFile
   find $targetDir/namenode* -type f -mtime +7 -exec rm {}  \;

}

function getSnapshot () {

   curl -s http://${nameNode}:50070/getimage?getimage=1 > $workDir/fsimage
   curl -s http://${nameNode}:50070/getimage?getedit=1 > $workDir/edits

   echo "$(date) Grabbed NameNode snapshot" >> $logFile

}

function zipSnapshot () {

   zip -qj $targetDir/namenode-$tsNow.zip $workDir/*

   echo "$(date) Compressed NameNode snapshot" >> $logFile

}

function cleanUp () {

   rm -f $workDir/edits
   rm -f $workDir/fsimage

   echo "$(date) Cleaned up work directory" >> $logFile

}

# Action starts here!
checkforLog
checkforTarget
checkforWorkDir
checkTargetSpace
checkIfSnapshotExists
checkForLastSnapshot
getSnapshot
zipSnapshot
cleanUp
compareSnapshotSizes
retireOldSnapshots

