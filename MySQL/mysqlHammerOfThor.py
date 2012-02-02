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

def getQueriesByTime(db, thresh):
   filter = "%system%"
   cursor = db.cursor()
   cursor.execute("SELECT id FROM information_schema.processlist WHERE time > %s AND user NOT LIKE '%s';" % (thresh, filter)) 
   queries = cursor.fetchall()
   cursor.close()
   return queries


def getQueriesByHost(db, filter):
   cursor = db.cursor()
   cursor.execute("SELECT id FROM information_schema.processlist WHERE host LIKE '%s';" % ('%' + filter + '%',)) 
   queries = cursor.fetchall()
   cursor.close()
   return queries


def killQueriesByID(db, queries):
   for id in queries:
     print 'Killing query %s' % id
     cursor = db.cursor()
     cursor.execute("KILL '%s';" % id)


if '__main__' == __name__:

   parser = optparse.OptionParser()
   parser.add_option('-s', '--server', help='Server to kill queries on.', dest='server', default=False, action='store')
   parser.add_option('-p', '--port', help='Port of above server (default: 3306).', dest='port', default=False, action='store')
   parser.add_option('-u', '--user', help='User that can kill queries (default: root).', dest='user', default=False, action='store')
   parser.add_option('-w', '--wildcard', help='Kills all queries from any host matching a wildcard string.', dest='host', default=False, action='store')
   parser.add_option('-t', '--threshold', help='Kills all queries that have been running longer than this value in seconds.', dest='thresh', default=False, action='store')

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

   if opts.host and opts.thresh:
      print "You can only specify one kill method."
      sys.exit(1)

   myPasswd=getpass.getpass("MySQL Password for %s: " % myUser) 

   if opts.host:
      # BTW, This will kill your own connecton to the server if the wildcard matches your own host.
      print "Killing all queries from hosts matching *%s*" % opts.host
      db = MySQLdb.connect(host=opts.server, port=myPort, user='root', passwd=myPasswd, db='information_schema')
      q = getQueriesByHost(db, opts.host)
      killQueriesByID(db, q) 
      db.close()

   elif opts.thresh:
      print "Killing all queries running longer than %s seconds" % opts.thresh
      db = MySQLdb.connect(host=opts.server, port=myPort, user='root', passwd=myPasswd, db='information_schema')
      q = getQueriesByTime(db, opts.thresh)
      killQueriesByID(db, q) 
      db.close()
      



  
