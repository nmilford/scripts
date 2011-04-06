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

# Creates an LVM snapshot of mysql.
# * Only notifies you if there is a problem and outpouts a log.
# * Retires snapshots older than a week.
# * Put it in cron to run daily.

# Script presumes that:
# * Database is in /var/lib/mysql
# * /var/lib/mysql is mounted on the Logical volume /dev/VolGroup/mdata
# * $target is an NFS mount in my environement.


email=you@example.com
tsToday=$(date +%F)
tsLast=$(date +%F -d yesterday)
mySocket=/var/lib/mysql/mysql.sock
lvmVG=/dev/VolGroup
lvmLV=$lvmVG/mdata
lvmSnap=$lvmVG/mysqlSnaphot-$tsToday
snapMount=/mnt/mysqlSnaphot-$tsToday
source=$lvmSnap/
sourceMount=/var/lib/mysql
target=/backup/mysql
snapToday=$target/mysqlSnapshot-$tsToday.tar.gz
snapLast=$target/mysqlSnapshot-$tsLast.tar.gz
snapSizeThresh=3
targetSpacePercent=$(/bin/df -h $target | /bin/sed -n '3p' | /bin/awk '{ print $4 }' | sed 's/.\{1\}$//')
targetSpaceThresh=91
logDir=$target/log
logFile=$logDir/backup.log

function checkforLog () {

   if [ ! -d $logDir ]; then

      errSubject="[$(hostname -s)] MySQL Snapshot Error:  Cannot log backup. ($tsToday)"
      errMessage="MySQL Snapshot Error:\n\n\t$logDir doesn't exist"

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      exit 1
   fi

}

function checkTargetSpace () {

   if [ $targetSpacePercent -ge $targetSpaceThresh ]; then

      errSubject="[$(hostname -s)] MySQL Snapshot Error:  Not enough free space on target. ($tsToday)"
      errMessage="MySQL Snapshot Error:\n\n\tFree Space on $target is $targetSpacePercent%, threshold is $targetSpaceThresh%"

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      echo "$(date) Free Space on $target is $targetSpacePercent%, threshold is $targetSpaceThresh%" >> $logFile
      exit 1
   fi

}

function checkIfSnapshotExists () {

   if [ -s $snapToday ]; then

      errSubject="[$(hostname -s)] MySQL Snapshot Error:  Snapshot already exists! ($tsToday)"
      errMessage="MySQL Snapshot Error:\n\n\tSnapshot script was halted because $(hostname -s):$snapToday already exists. Please investigate why and restart the snapshot manually."

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      exit 1
      echo "$(date) Today's snapshot ($(hostname -s):$snapToday) not exists, exiting! " >> $logFile
   fi

}

function checkForLastSnapshot () {

   if [ ! -s $snapLast ]; then

      errSubject="[$(hostname -s)] MySQL Snapshot Notice:  Yesterday's snapshot does not exist! ($tsToday)"
      errMessage="MySQL Snapshot Notice:\n\n\tThis is only informational, but $(hostname -s):$snapLast does not exist.\n\n\tToday's snapshot will continue to run but please investigate why Yesterday's ($tsLast) snapshot did not complete."

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      echo "$(date) Yesterday's snapshot ($(hostname -s):$snapLast) does not exist! " >> $logFile
   fi

}

function compareSnapshotSizes () {

   snapTodaySize=$(stat -c%s $snapToday)
   snapLastSize=$(stat -c%s $snapLast)
   percentDiff=$(echo "scale=3; ( $snapTodaySize - $snapLastSize  ) / $snapLastSize  * 100"  | /usr/bin/bc -l | /bin/sed 's/\-//g')

   if [ $(echo "$percentDiff > $snapSizeThresh" | /usr/bin/bc -l) -eq 1 ]; then

      errSubject="[$(hostname -s)] MySQL Snapshot Notice:  Percent change in snapshot size is too great! ($tsToday)"
      errMessage="MySQL Snapshot Notice:\n\n\tThis is only informational, but the size difference between $(hostname -s):$snapToday and $(hostname -s):$snapLast is greater than the current threshold of $snapSizeThresh%.\n\n\t\t$(hostname -s):$snapLast is $snapLastSize bytes.\n\t\t$(hostname -s):$snapToday is $snapTodaySize bytes.\n\n\tToday's snapshot script has completed, but please investigate the size discrepancy as it may be an indication of a bad snapshot."

      echo -e "$errMessage" | /bin/mail -s "$errSubject" $email
      echo "$(date) The size difference between $(hostname -s):$snapToday and $(hostname -s):$snapLast is greater than the current threshold of $snapSizeThresh%." >> $logFile
   fi

}

function makeMountPoint () {

   if [ ! -d $snapMount ]; then
      /bin/mkdir -p $snapMount
   else
      /bin/umount -l $snapMount
      /bin/rm -rf $snapMount
      /bin/mkdir -p $snapMount
   fi

   echo "$(date) Creating mount point." >> $logFile

}

function stopSlave () { 

   /usr/bin/mysql -uroot -S $mySocket -e"STOP SLAVE;" 

   echo "$(date) Stoping slave process." >> $logFile

}

function startSlave () {

   /usr/bin/mysql -uroot -S $mySocket -e"START SLAVE;" 

   echo "$(date) Starting slave process." >> $logFile

}

function getLogPosition () {

   binlogName=$(/usr/bin/mysql -uroot -S $mySocket -e"SHOW SLAVE STATUS\G;" | /bin/grep -m1 Master_Log_File: | /bin/cut -d":" -f2 | /usr/bin/xargs)
   binlogPos=$(/usr/bin/mysql -uroot -S $mySocket -e"SHOW SLAVE STATUS\G;" | /bin/grep -m1 Read_Master_Log_Pos:| /bin/cut -d":" -f2 | /usr/bin/xargs)

   echo "$(date) Getting log positions." >> $logFile

}

function putSlaveSql () {

echo "CHANGE MASTER TO 
MASTER_HOST='mysqlmaster.example.com',
MASTER_USER='repl',
MASTER_PASSWORD='password',
MASTER_PORT=3306,
MASTER_LOG_FILE='$binlogName',
MASTER_LOG_POS=$binlogPos,
MASTER_CONNECT_RETRY=10;"  > $snapMount/startSlave-$tsToday.sql

   echo "$(date) CHANGE MASTER statement generated and placed." >> $logFile

}

function copyConfig () {

   cp -f /etc/my.cnf $snapMount/$(hostname -s)-$tsToday-my.cnf

   echo "$(date) my.cnf placed." >> $logFile

}

function makeLvmSnapshot () {

# The snapshot must be made within the SQL session or the lock will be lost.

/usr/bin/mysql -uroot -S $mySocket <<SQL_EOF 
FLUSH TABLES WITH READ LOCK;
FLUSH LOGS;
SYSTEM /usr/sbin/lvcreate -L10G -s -n mysqlSnaphot-$tsToday $lvmLV
UNLOCK TABLES;
SQL_EOF

   echo "$(date) snapshot created." >> $logFile

}

function mountSnapshot () {

   sourceFileSystem=$(/bin/mount | /bin/grep $sourceMount | /bin/awk '{print $5}')

   if [ $sourceFileSystem == "xfs" ]; then
      /bin/mount -o rw,nouuid $lvmSnap $snapMount
   else
      /bin/mount $lvmSnap $snapMount
   fi

   echo "$(date) snapshot mounted." >> $logFile

}

function unmountSnapshot () {

   /bin/umount -l $snapMount

   echo "$(date) snapshot unmounted." >> $logFile

}

function removeLvmSnapshot () {

   /usr/sbin/lvremove -f $lvmSnap

   echo "$(date) removing snapshot." >> $logFile

}

function clearMountPoint () {

   if [ -d $snapMount ]; then
      /bin/rm -rf $snapMount
   fi

   echo "$(date) mount point removed." >> $logFile

}

function shipSnapshot () {

   echo "$(date) starting to compress snapshot." >> $logFile

   if [ -x /usr/bin/pigz ]; then
      tar --use-compress-program pigz -cf $snapToday $snapMount/prod4
   else
      tar -czf $snapToday $snapMount/prod4
   fi

   echo "$(date) snapshot compressed." >> $logFile

}

function retireOldSnapshots () {

   find $target/mysqlSnapshot* -type f -mtime +7 -exec echo "$(date) retiring backup: " {}  \; >> $logFile
   find $target/mysqlSnapshot* -type f -mtime +7 -exec rm {}  \;

}

# Action Starts Here!
checkforLog
checkTargetSpace
retireOldSnapshots
checkForLastSnapshot
checkIfSnapshotExists
makeMountPoint
stopSlave
getLogPosition
makeLvmSnapshot
startSlave
mountSnapshot
putSlaveSql
copyConfig
shipSnapshot
unmountSnapshot
removeLvmSnapshot
clearMountPoint
compareSnapshotSizes

