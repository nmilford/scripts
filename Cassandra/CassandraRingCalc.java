/*
 Copyright 2011, Nathan Milford

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

 Takes as argument the number of nodes in your cluster and returns
 the token ranges you can use on each of your nodes to balance.

 You can read more here:
   http://wiki.apache.org/cassandra/Operations#Load_balancing
*/

// CassandraRingCalc.java

import java.io.*;
import java.math.BigInteger;

public class CassandraRingCalc {

   public static void main (String[] args) {

      String input = null;
      int numNodes = 0;
      double initToken = 0;

      try {
         System.out.print("Number of Cassandra Nodes: ");
         BufferedReader is = new BufferedReader(
            new InputStreamReader(System.in));
            input = is.readLine();
            numNodes = Integer.parseInt(input);
      } catch (NumberFormatException ex) {
         System.err.println("Not a valid number: " + input);
      } catch (IOException e) {
         System.err.println("Unexpected IO ERROR: " + e);
      }

      BigInteger tok = new BigInteger("170141183460469231731687303715884105728");

      for(int i=0; i<numNodes; i++){
        
         System.out.println("Node: " + i);
         System.out.println("        initial_token: " + tok.multiply(BigInteger.valueOf(i)).divide(BigInteger.valueOf(numNodes)));

      }
   }
}

