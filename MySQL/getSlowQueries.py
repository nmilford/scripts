#!/usr/bin/env python

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

import sys
import MySQLdb
import optparse
import getpass

# This script uses the information_schema.processlist table which does not
# exist prior to MySQL 5.1.

def printQueriesByTime(db, thresh):
   filter = "%system%"
   cursor = db.cursor(cursorclass=MySQLdb.cursors.DictCursor)
   cursor.execute("SELECT * FROM information_schema.processlist WHERE time > %s AND user NOT LIKE '%s' AND info NOT LIKE 'NULL' ORDER BY time DESC;" % (thresh, filter)) 
   rows = cursor.fetchall()
   cursor.close()
   for row in rows:
      print "*************************************************************"
      print "Query %s by %s running for %s seconds:" % (row['ID'], row['HOST'], row['TIME'])
      print ""
      print row['INFO']
   print "*************************************************************"

if '__main__' == __name__:

   parser = optparse.OptionParser()
   parser.add_option('-s', '--server', help='Server to get queries on.', dest='server', default=False, action='store')
   parser.add_option('-p', '--port', help='Port of above server (default: 3306).', dest='port', default=False, action='store')
   parser.add_option('-u', '--user', help='User that can access the information_schema (default: root).', dest='user', default=False, action='store')
   parser.add_option('-t', '--threshold', help='Returns  all queries that have been running longer than this value in seconds (default: 3).', dest='thresh', default=False, action='store')

   (opts, args) = parser.parse_args()

   if len(sys.argv)<2:
      print "You must specify some options, run %s -h for help." % sys.argv[0]
      sys.exit(1)

   if not opts.server:
      print "You must specify a server, run %s -h for help." % sys.argv[0]
      sys.exit(1)

   if not opts.port:
      myPort = 3306
   else:
      myPort = opts.port

   if not opts.user:
      myUser = "root"
   else:
      myUser = opts.user 

   if not opts.thresh:
      myThresh = "3"
   else:
      myThresh = opts.thresh

   myPasswd=getpass.getpass("MySQL Password for %s: " % myUser) 

   print "Printing all queries running longer than %s seconds" % myThresh
   db = MySQLdb.connect(host=opts.server, port=myPort, user=myUser, passwd=myPasswd, db='information_schema')
   printQueriesByTime(db, myThresh)
   db.close()
