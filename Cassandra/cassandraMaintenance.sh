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

logFile="/var/log/cassandra/mainenance.log"

# Older Cassandra insalls use 8080, noewer ones use 7199.
jmxPort=7199

checkForNodetool() {
  if [ ! -x /usr/bin/nodetool ]; then
    echo "nodetool not found."
    exit 1
  fi
}

runRepair() {
  echo "$keyspace.$columnfamily repair started at $(date)" >> $logFile
  nodetool -h $HOSTNAME -p $jmxPort repair $keyspace $columnfamily
  echo "$keyspace.$columnfamily repair completed at $(date)" >> $logFile
}

runCompaction() {
  echo "$keyspace.$columnfamily compaction started at $(date)" >> $logFile
  nodetool -h $HOSTNAME -p $jmxPort compact $keyspace $columnfamily
  echo "$keyspace.$columnfamily compaction completed at $(date)" >> $logFile
}

runCleanup() {
  echo "$keyspace.$columnfamily cleanup started at $(date)" >> $logFile
  nodetool -h $HOSTNAME -p $jmxPort cleanup $keyspace $columnfamily
  echo "$keyspace.$columnfamily cleanup completed at $(date)" >> $logFile
}

reportRuntime() {
  S=$SECONDS
  ((h=S/3600))
  ((m=S%3600/60))
  ((s=S%60))
  echo "Total Run Time was $h:$m:$s" >> $logFile
}

getKeyspaces() {
  echo "show keyspaces;" > /var/tmp/ks.cmd
  keyspaces=( $(cassandra-cli -h $HOSTNAME -p 9160 -f /var/tmp/ks.cmd 2>&1 | grep Keyspace | grep -v 'system\|OpsCenter' | awk {' print $2 '} | sed 's/://' ) )
  rm -f /var/tmp/ks.cmd
}

getColumnfamilies() {
  echo "describe $keyspace;" > /var/tmp/cf.cmd
  columnfamilies=( $(cassandra-cli -h $HOSTNAME -p 9160 -f /var/tmp/cf.cmd 2>&1 | grep ColumnFamily | awk {' print $2 '} | sed 's/://' ) )
  rm -f /var/tmp/cf.cmd
}

main() {
  checkForNodetool
  getKeyspaces
  for keyspace in "${keyspaces[@]}"; do
    getColumnfamilies
    for columnfamily in "${columnfamilies[@]}"; do
      runRepair
      runCompaction
      runCleanup
      reportRuntime
    done
  done
}

main
