import edu.uci.ics.jung.algorithms.scoring.*;
import edu.uci.ics.jung.algorithms.shortestpath.*;
import edu.uci.ics.jung.graph.*;
import edu.uci.ics.jung.graph.util.*;
import edu.uci.ics.jung.algorithms.cluster.*;
import java.io.*;
import java.util.regex.*;

public class Calc {
    public static void main(String[] args) throws Exception {
        Graph<String, Integer> g = new DirectedSparseGraph<String, Integer> ();
        BufferedReader f = new BufferedReader(new FileReader("berlin.dot"));
        String line;
        Pattern p = Pattern.compile("\"(.*)\" -> \"(.*)\";");
        int id = 0;
        while ((line = f.readLine()) != null)   {
            Matcher m = p.matcher(line);
            if(m.matches()) {
                g.addEdge(id,m.group(1),m.group(2),EdgeType.DIRECTED);
                id++;
            }
        }
        System.out.print(id);
        System.out.println(" imported.");
        PageRank<String, Integer> pr = new PageRank<String, Integer>(g, 0.15);
        for(int i = 0 ; i< 25; i++) {
            System.out.format("Step %d\n", i);
            pr.step();
        }
        for(String v : g.getVertices()) {
            System.out.format("%f: %s\n",pr.getVertexScore(v),v);
        }
    }
}

