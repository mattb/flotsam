import edu.uci.ics.jung.algorithms.scoring.*;
import edu.uci.ics.jung.algorithms.shortestpath.*;
import edu.uci.ics.jung.graph.*;
import edu.uci.ics.jung.graph.util.*;
import edu.uci.ics.jung.algorithms.cluster.*;
import java.io.*;
import java.util.*;
import java.util.regex.*;

public class Ranker {
    public Map rank(Map network) throws Exception {
        Graph<String, Integer> g = new DirectedSparseGraph<String, Integer> ();
        int count = 0;
        for(Object e : network.entrySet()) {
            Map.Entry entry = (Map.Entry)e;
            String user = (String)entry.getKey();
            List follows = (List)entry.getValue();
            for(Object fuser : follows) {
                g.addEdge(count,user,(String)fuser,EdgeType.DIRECTED);
                count++;
            }
        }
        /*PageRank<String, Integer> pr = new PageRank<String, Integer>(g, 0.15);
        for(int i = 0 ; i< 25; i++) {
            pr.step();
        }
        */
        BetweennessCentrality<String, Integer> pr = new BetweennessCentrality<String, Integer>(g);
        HashMap<String,Double> result = new HashMap<String,Double>();
        for(String v : g.getVertices()) {
            result.put(v,pr.getVertexScore(v));
        }
        return result;
    }
}

