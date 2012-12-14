#!/bin/bash

# Copyright 2012, Nathan Milford
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


usage="usage: $0 -k <keyspace> -c [<column family> or 'all']"

# Place your columnfamilies in this array seperated by a space. 
columnFamilies=(list your column families here)

# Older Cassandra insalls use 8080, noewer ones use 7199.
jmxPort=7199

logFile="/var/log/cassandra/maintenance.log"

function checkForNodetool() {
   if [ ! -x /usr/bin/nodetool ]; then
      echo "nodetool not found."
      exit 1
   fi
}

function runRepair() {
   echo "$keyspace.$columnFamily repair started at $(date)" >> $logFile
   nodetool -h $HOSTNAME -p $jmxPort repair $keyspace $columnFamily
   echo "$keyspace.$columnFamily repair completed at $(date)" >> $logFile
}

function runCompaction() {
   echo "$keyspace.$columnFamily compaction started at $(date)" >> $logFile
   nodetool -h $HOSTNAME -p $jmxPort compact $keyspace $columnFamily
   echo "$keyspace.$columnFamily compaction completed at $(date)" >> $logFile
}

function runCleanup() {
   echo "$keyspace.$columnFamily cleanup started at $(date)" >> $logFile
   nodetool -h $HOSTNAME -p $jmxPort cleanup $keyspace $columnFamily
   echo "$keyspace.$columnFamily cleanup completed at $(date)" >> $logFile
}

function reportRuntime() {
   S=$SECONDS
   ((h=S/3600))
   ((m=S%3600/60))
   ((s=S%60))
   echo "Total Run Time was $h:$m:$s" >> $logFile
}


while getopts ":k:c:" options; do
   case $options in
      k ) keyspace=$OPTARG;;
      c ) columnFamily=$OPTARG;;
      * ) echo $usage
          exit 1;;
   esac
done

if [[ -z $keyspace ]] || [[ -z $columnFamily ]]; then
   echo $usage
   exit 1
fi

if [ $columnFamily == "all" ]; then
   for cf in "${columnFamilies[@]}"; do
      columnFamily=$cf
      runRepair
      runCompaction
      runCleanup
      reportRuntime
   done
else
   runRepair
   runCompaction
   runCleanup
   reportRuntime
fi

