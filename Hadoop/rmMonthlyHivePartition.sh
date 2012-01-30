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

# Deletes monthly partitions in hive and thier data on HDFS.

# BE SURE TO CHANGE 'example.com' TO THE TLD OF YOUR NAMENODE IN THE SED STATEMENT BELOW

usage="usage: $0 -t <table> -y <year> -m <month>"

while getopts ":t:y:m:" options; do
   case $options in
      t ) table=$OPTARG;;
      y ) year=$OPTARG;;
      m ) month=$OPTARG;;
      * ) echo $usage
            exit 1;;
     esac
done

if [[ -z $month ]] || [[ -z $table ]] || [[ -z $year ]]; then
   echo $usage
   exit 1
fi

# CHANGE ME
hdfsPath=$(hive -S -e "DESCRIBE EXTENDED $table;" | tail -1 | sed -e 's/.*example.com//' | cut -d',' -f1)

IFS=$'\n'

partitions=$( (hive -S -e "SHOW PARTITIONS $table;" | grep $year-$month) )

for partition in $partitions; do
   echo "Removing $partition at $hdfsPath/$table/$partition/" 
   partition_spec=$(echo $partition | cut -d"=" -f1)
   partition_crit=$(echo $partition | cut -d"=" -f2)
   hive -S -e "ALTER TABLE $table DROP PARTITION ($partition_spec='$partition_crit');" 
   hadoop fs -rmr -skipTrash "$hdfsPath/$table/$partition/"
done

