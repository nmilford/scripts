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

# Hive doesn't always do a good job cleaning up afer itself.  This script
# checks to see if any jobs are running (that might be using data in hdfs://tmp
# and if none are running, deletes all of the directories under hdfs://tmp
# excluding beeswax directories.

checkForRunningJobs() {

   runningJobs=$(hadoop job -list | grep running | awk '{ print $1 }')

   if [ $? -ne 0 ]; then
      echo "ERROR: failure with hadoop command."
      exit 1
   fi

   if [ $runningJobs != 0 ]; then
      echo "Jobs currently running, will not continue."
      exit 1
   fi

}

getTempDirs() {

   tempDirs=( $(hadoop fs -ls /tmp | grep -v beeswax | grep -v Found  | awk '{ print $8 }') )

   if [ $? -ne 0 ]; then
      echo "ERROR: failure with hadoop command."
      exit 1
   fi

}

deleteTempDirs() {

   getTempDirs

   for dir in ${tempDirs[@]}; do
      echo "hadoop fs -rmr $dir"
      if [ $? -ne 0 ]; then
         echo "ERROR: failure with hadoop command."
         exit 1
      fi
   done

}

getTempSpaceUsed() {

   tmpSpaceUsed=$(hadoop fs -dus /tmp | awk '{ print $2 }')

   if [ $? -ne 0 ]; then
      echo "ERROR: failure with hadoop command."
      exit 1
   fi

}

calcSpaceReclaimed() {

   spaceReclaimed=$(($spaceBefore - $spaceAfter))

   echo "$(echo ${spaceReclaimed}/1024/1024 | bc) Megabytes Reclaimed."

}

main() {

   getTempSpaceUsed ; spaceBefore=tmpSpaceUsed

   checkForRunningJobs

   deleteTempDirs

   getTempSpaceUsed ; spaceAfter=tmpSpaceUsed
   
   calcSpaceReclaimed

}

main
