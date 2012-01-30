#!/usr/bin/env python
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

# Takes as argument the number of nodes in your cluster and returns
# the token ranges you can use on each of your nodes to balance.

# Pretty much ripped off from:
#   http://wiki.apache.org/cassandra/Operations#Load_balancing
#
# I just wraped it up in a script.

import sys
nodes = int(sys.argv[1])
for x in xrange(nodes):
   print "Node", x, "initial_token:", 2 ** 127 / nodes * x


