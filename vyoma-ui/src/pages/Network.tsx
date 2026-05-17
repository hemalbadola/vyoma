import { useEffect, useState, useRef } from 'react';
import { useAuth } from '../contexts/AuthContext';
import Sidebar from '../components/Sidebar';
import './Network.css';

interface Citation {
  id: number;
  source_paper_id: string;
  target_paper_id: string;
  citation_context: string | null;
}

interface Paper {
  id: string;
  title: string;
  authors: string[];
  year: number | null;
  cited_by_count: number;
}

interface GraphNode {
  id: string;
  title: string;
  x: number;
  y: number;
  vx: number;
  vy: number;
  connections: number;
}

interface GraphEdge {
  source: string;
  target: string;
}

export default function Network() {
  const { user, getApiToken } = useAuth();
  const [citations, setCitations] = useState<Citation[]>([]);
  const [papers, setPapers] = useState<Map<string, Paper>>(new Map());
  const [loading, setLoading] = useState(true);
  const [selectedPaper, setSelectedPaper] = useState<Paper | null>(null);
  const [nodes, setNodes] = useState<GraphNode[]>([]);
  const [edges, setEdges] = useState<GraphEdge[]>([]);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animationRef = useRef<number | undefined>(undefined);

  useEffect(() => {
    if (!user) return;

    // Mock data for showcase
    const mockPapers = new Map<string, Paper>([
      ['1', { id: '1', title: 'Attention Is All You Need', authors: ['Vaswani, A.'], year: 2017, cited_by_count: 98743 }],
      ['2', { id: '2', title: 'BERT', authors: ['Devlin, J.'], year: 2019, cited_by_count: 67432 }],
      ['3', { id: '3', title: 'GPT-3', authors: ['Brown, T.'], year: 2020, cited_by_count: 45678 }],
      ['4', { id: '4', title: 'ResNet', authors: ['He, K.'], year: 2016, cited_by_count: 156234 }],
      ['5', { id: '5', title: 'VGG', authors: ['Simonyan, K.'], year: 2015, cited_by_count: 89432 }],
    ]);

    const mockCitations: Citation[] = [
      { id: 1, source_paper_id: '2', target_paper_id: '1', citation_context: 'Based on transformer architecture' },
      { id: 2, source_paper_id: '3', target_paper_id: '1', citation_context: 'Uses attention mechanism' },
      { id: 3, source_paper_id: '3', target_paper_id: '2', citation_context: 'Builds on BERT' },
      { id: 4, source_paper_id: '5', target_paper_id: '4', citation_context: 'Inspired by ResNet' },
    ];

    setPapers(mockPapers);
    setCitations(mockCitations);
    buildGraph(mockCitations, mockPapers);
    setLoading(false);
  }, [user]);

  const buildGraph = (citationsData: Citation[], papersMap: Map<string, Paper>) => {
    const nodeMap = new Map<string, GraphNode>();
    const edgesList: GraphEdge[] = [];

    // Count connections
    const connectionCount = new Map<string, number>();
    citationsData.forEach(citation => {
      connectionCount.set(citation.source_paper_id, (connectionCount.get(citation.source_paper_id) || 0) + 1);
      connectionCount.set(citation.target_paper_id, (connectionCount.get(citation.target_paper_id) || 0) + 1);
    });

    // Create nodes
    const canvas = canvasRef.current;
    const centerX = canvas ? canvas.width / 2 : 400;
    const centerY = canvas ? canvas.height / 2 : 300;

    papersMap.forEach((paper, id) => {
      const angle = Math.random() * Math.PI * 2;
      const radius = 100 + Math.random() * 200;
      nodeMap.set(id, {
        id,
        title: paper.title,
        x: centerX + Math.cos(angle) * radius,
        y: centerY + Math.sin(angle) * radius,
        vx: 0,
        vy: 0,
        connections: connectionCount.get(id) || 0,
      });
    });

    // Create edges
    citationsData.forEach(citation => {
      if (nodeMap.has(citation.source_paper_id) && nodeMap.has(citation.target_paper_id)) {
        edgesList.push({
          source: citation.source_paper_id,
          target: citation.target_paper_id,
        });
      }
    });

    setNodes(Array.from(nodeMap.values()));
    setEdges(edgesList);
  };

  useEffect(() => {
    if (nodes.length === 0 || !canvasRef.current) return;

    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Set canvas size
    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;

    const animate = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // Apply forces
      const k = 0.1; // Spring constant
      const repulsion = 5000;
      const damping = 0.9;

      nodes.forEach(node1 => {
        // Repulsion between nodes
        nodes.forEach(node2 => {
          if (node1.id === node2.id) return;
          const dx = node2.x - node1.x;
          const dy = node2.y - node1.y;
          const dist = Math.sqrt(dx * dx + dy * dy) || 1;
          const force = repulsion / (dist * dist);
          node1.vx -= (dx / dist) * force;
          node1.vy -= (dy / dist) * force;
        });

        // Attraction along edges
        edges.forEach(edge => {
          let other: GraphNode | undefined;
          if (edge.source === node1.id) {
            other = nodes.find(n => n.id === edge.target);
          } else if (edge.target === node1.id) {
            other = nodes.find(n => n.id === edge.source);
          }

          if (other) {
            const dx = other.x - node1.x;
            const dy = other.y - node1.y;
            node1.vx += dx * k;
            node1.vy += dy * k;
          }
        });

        // Center gravity
        const dx = canvas.width / 2 - node1.x;
        const dy = canvas.height / 2 - node1.y;
        node1.vx += dx * 0.01;
        node1.vy += dy * 0.01;

        // Apply velocity
        node1.vx *= damping;
        node1.vy *= damping;
        node1.x += node1.vx;
        node1.y += node1.vy;

        // Boundary
        node1.x = Math.max(20, Math.min(canvas.width - 20, node1.x));
        node1.y = Math.max(20, Math.min(canvas.height - 20, node1.y));
      });

      // Draw edges
      ctx.strokeStyle = 'rgba(100, 116, 139, 0.2)';
      ctx.lineWidth = 1;
      edges.forEach(edge => {
        const source = nodes.find(n => n.id === edge.source);
        const target = nodes.find(n => n.id === edge.target);
        if (source && target) {
          ctx.beginPath();
          ctx.moveTo(source.x, source.y);
          ctx.lineTo(target.x, target.y);
          ctx.stroke();
        }
      });

      // Draw nodes
      nodes.forEach(node => {
        const radius = 5 + Math.sqrt(node.connections) * 3;
        ctx.fillStyle = node.id === selectedPaper?.id ? '#2563eb' : '#64748b';
        ctx.beginPath();
        ctx.arc(node.x, node.y, radius, 0, Math.PI * 2);
        ctx.fill();

        // Draw label for selected node
        if (node.id === selectedPaper?.id) {
          ctx.fillStyle = '#1f2937';
          ctx.font = '12px sans-serif';
          const label = node.title.length > 50 ? node.title.substring(0, 50) + '...' : node.title;
          ctx.fillText(label, node.x + radius + 5, node.y + 4);
        }
      });

      animationRef.current = requestAnimationFrame(animate);
    };

    animate();

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [nodes, edges, selectedPaper]);

  const handleCanvasClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    // Find clicked node
    for (const node of nodes) {
      const radius = 5 + Math.sqrt(node.connections) * 3;
      const dist = Math.sqrt((x - node.x) ** 2 + (y - node.y) ** 2);
      if (dist <= radius) {
        const paper = papers.get(node.id);
        setSelectedPaper(paper || null);
        return;
      }
    }

    setSelectedPaper(null);
  };

  const deleteCitation = async (citationId: number) => {
    if (!user) return;
    
    if (!confirm('Remove this citation link?')) return;

    try {
      const token = await getApiToken();
      const response = await fetch(`https://paperverse-kvw2y.ondigitalocean.app/api/citations/${citationId}`, {
        method: 'DELETE',
        headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      });

      if (!response.ok) throw new Error('Failed to delete citation');

      const updatedCitations = citations.filter(c => c.id !== citationId);
      setCitations(updatedCitations);
      buildGraph(updatedCitations, papers);
    } catch (err) {
      console.error('Error deleting citation:', err);
      alert('Failed to delete citation');
    }
  };

  if (!user) return null;

  return (
    <div className="dashboard-wrapper">
      <div className="dashboard-bg">
        <div className="bg-gradient"></div>
        <div className="bg-grid"></div>
      </div>

      <Sidebar user={user} />

      <main className="main-content">
        <header className="main-header">
          <div>
            <h2 className="welcome-text">Citation Network</h2>
            <p className="subtitle-text">
              {papers.size} papers • {citations.length} connections
            </p>
          </div>
        </header>

        <div className="network-container">
          {loading ? (
            <div className="network-loading">
              <div className="loading-spinner"></div>
              <p>Building citation network...</p>
            </div>
          ) : nodes.length > 0 ? (
            <>
              <canvas
                ref={canvasRef}
                className="network-canvas"
                onClick={handleCanvasClick}
              />

              <div className="network-legend">
                <h4>Legend</h4>
                <div className="legend-item">
                  <div className="legend-node small"></div>
                  <span>Few connections</span>
                </div>
                <div className="legend-item">
                  <div className="legend-node large"></div>
                  <span>Many connections</span>
                </div>
                <p className="legend-hint">Click nodes to view details</p>
              </div>

              {selectedPaper && (
                <div className="paper-detail-panel">
                  <button className="close-btn" onClick={() => setSelectedPaper(null)}>×</button>
                  <h3>{selectedPaper.title}</h3>
                  <p className="paper-authors">
                    {selectedPaper.authors.slice(0, 3).join(', ')}
                    {selectedPaper.authors.length > 3 ? ', et al.' : ''}
                  </p>
                  <div className="paper-meta">
                    {selectedPaper.year && <span>{selectedPaper.year}</span>}
                    <span>📊 {selectedPaper.cited_by_count} citations</span>
                  </div>

                  <h4>Connected Citations</h4>
                  <div className="citation-list">
                    {citations
                      .filter(c => c.source_paper_id === selectedPaper.id || c.target_paper_id === selectedPaper.id)
                      .map(citation => {
                        const otherId = citation.source_paper_id === selectedPaper.id 
                          ? citation.target_paper_id 
                          : citation.source_paper_id;
                        const otherPaper = papers.get(otherId);
                        
                        return (
                          <div key={citation.id} className="citation-item">
                            <div>
                              <strong>
                                {citation.source_paper_id === selectedPaper.id ? '→' : '←'}
                              </strong>
                              <span>{otherPaper?.title || 'Unknown Paper'}</span>
                            </div>
                            <button 
                              className="delete-citation-btn"
                              onClick={() => deleteCitation(citation.id)}
                            >
                              🗑️
                            </button>
                          </div>
                        );
                      })}
                  </div>
                </div>
              )}
            </>
          ) : (
            <div className="network-empty">
              <svg viewBox="0 0 24 24" fill="none" width="64" height="64">
                <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="2"/>
                <circle cx="6" cy="6" r="2" stroke="currentColor" strokeWidth="2"/>
                <circle cx="18" cy="6" r="2" stroke="currentColor" strokeWidth="2"/>
                <circle cx="6" cy="18" r="2" stroke="currentColor" strokeWidth="2"/>
                <circle cx="18" cy="18" r="2" stroke="currentColor" strokeWidth="2"/>
                <line x1="12" y1="9" x2="12" y2="6" stroke="currentColor" strokeWidth="2"/>
                <line x1="9" y1="12" x2="6" y2="12" stroke="currentColor" strokeWidth="2"/>
              </svg>
              <h3>No Citations Yet</h3>
              <p>Add citation links between your papers to build your network</p>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
