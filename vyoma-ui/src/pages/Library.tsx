import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import Sidebar from '../components/Sidebar';
import './Library.css';

interface Paper {
  id: string;
  title: string;
  authors: string[];
  year: number | null;
  venue: string | null;
  cited_by_count: number;
  abstract: string | null;
  doi: string | null;
  pdf_url: string | null;
  is_open_access: boolean;
  concepts: string[];
  saved_at?: string;
}

type ViewMode = 'grid' | 'list';
type FilterType = 'all' | 'open-access' | 'recent';
type SortType = 'saved-desc' | 'saved-asc' | 'citations-desc' | 'year-desc';

export default function Library() {
  const { user, loading: authLoading, getApiToken } = useAuth();
  const [papers, setPapers] = useState<Paper[]>([]);
  const [filteredPapers, setFilteredPapers] = useState<Paper[]>([]);
  const [loading, setLoading] = useState(true);
  const [viewMode, setViewMode] = useState<ViewMode>('grid');
  const [filterType, setFilterType] = useState<FilterType>('all');
  const [sortType, setSortType] = useState<SortType>('saved-desc');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedYear, setSelectedYear] = useState<number | null>(null);
  const navigate = useNavigate();

  useEffect(() => {
    if (authLoading) return;
    
    if (!user) {
      navigate('/login');
      return;
    }

    // Mock data for showcase
    const mockPapers: Paper[] = [
      {
        id: '1',
        title: 'Attention Is All You Need',
        authors: ['Vaswani, A.', 'Shazeer, N.', 'Parmar, N.'],
        year: 2017,
        venue: 'NeurIPS',
        cited_by_count: 98743,
        abstract: 'The dominant sequence transduction models are based on complex recurrent or convolutional neural networks...',
        doi: '10.48550/arXiv.1706.03762',
        pdf_url: 'https://arxiv.org/pdf/1706.03762.pdf',
        is_open_access: true,
        concepts: ['Transformers', 'Neural Networks', 'NLP'],
        saved_at: new Date().toISOString(),
      },
      {
        id: '2',
        title: 'BERT: Pre-training of Deep Bidirectional Transformers',
        authors: ['Devlin, J.', 'Chang, M.', 'Lee, K.'],
        year: 2019,
        venue: 'NAACL',
        cited_by_count: 67432,
        abstract: 'We introduce a new language representation model called BERT...',
        doi: '10.18653/v1/N19-1423',
        pdf_url: 'https://arxiv.org/pdf/1810.04805.pdf',
        is_open_access: true,
        concepts: ['BERT', 'Language Models', 'Transfer Learning'],
        saved_at: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      },
      {
        id: '3',
        title: 'Deep Residual Learning for Image Recognition',
        authors: ['He, K.', 'Zhang, X.', 'Ren, S.'],
        year: 2016,
        venue: 'CVPR',
        cited_by_count: 156234,
        abstract: 'Deeper neural networks are more difficult to train. We present a residual learning framework...',
        doi: '10.1109/CVPR.2016.90',
        pdf_url: null,
        is_open_access: false,
        concepts: ['ResNet', 'Computer Vision', 'Deep Learning'],
        saved_at: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(),
      },
    ];

    setPapers(mockPapers);
    setFilteredPapers(mockPapers);
    setLoading(false);
  }, [user, navigate, authLoading]);

  useEffect(() => {
    let filtered = [...papers];

    // Apply filters
    if (filterType === 'open-access') {
      filtered = filtered.filter(p => p.is_open_access);
    } else if (filterType === 'recent') {
      const oneMonthAgo = new Date();
      oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);
      filtered = filtered.filter(p => p.saved_at && new Date(p.saved_at) >= oneMonthAgo);
    }

    // Apply year filter
    if (selectedYear) {
      filtered = filtered.filter(p => p.year === selectedYear);
    }

    // Apply search
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(p =>
        p.title.toLowerCase().includes(query) ||
        p.authors.some(a => a.toLowerCase().includes(query)) ||
        p.abstract?.toLowerCase().includes(query)
      );
    }

    // Apply sorting
    filtered.sort((a, b) => {
      switch (sortType) {
        case 'saved-desc':
          return (b.saved_at || '').localeCompare(a.saved_at || '');
        case 'saved-asc':
          return (a.saved_at || '').localeCompare(b.saved_at || '');
        case 'citations-desc':
          return b.cited_by_count - a.cited_by_count;
        case 'year-desc':
          return (b.year || 0) - (a.year || 0);
        default:
          return 0;
      }
    });

    setFilteredPapers(filtered);
  }, [papers, filterType, selectedYear, searchQuery, sortType]);

  const deletePaper = async (paperId: string) => {
    if (!user) return;
    
    if (!confirm('Are you sure you want to remove this paper from your library?')) return;

    try {
      const token = await getApiToken();
      const response = await fetch(`https://paperverse-kvw2y.ondigitalocean.app/api/papers/${paperId}`, {
        method: 'DELETE',
        headers: {
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });

      if (!response.ok) {
        throw new Error('Failed to delete paper');
      }

      setPapers(papers.filter(p => p.id !== paperId));
    } catch (err) {
      console.error('Error deleting paper:', err);
      alert('Failed to delete paper');
    }
  };

  const copyCitation = (paper: Paper) => {
    const authors = paper.authors.slice(0, 3).join(', ') + (paper.authors.length > 3 ? ', et al.' : '');
    const citation = `${authors}. "${paper.title}". ${paper.venue || 'Unknown Venue'}, ${paper.year || 'n.d.'}.`;
    navigator.clipboard.writeText(citation);
    alert('Citation copied to clipboard!');
  };

  const availableYears = Array.from(new Set(papers.map(p => p.year).filter(Boolean))).sort((a, b) => (b || 0) - (a || 0));

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
            <h2 className="welcome-text">Your Library</h2>
            <p className="subtitle-text">{papers.length} saved papers</p>
          </div>
          
          <div style={{ display: 'flex', gap: '12px' }}>
            <button 
              className={`view-toggle ${viewMode === 'grid' ? 'active' : ''}`}
              onClick={() => setViewMode('grid')}
            >
              Grid
            </button>
            <button 
              className={`view-toggle ${viewMode === 'list' ? 'active' : ''}`}
              onClick={() => setViewMode('list')}
            >
              List
            </button>
          </div>
        </header>

        <div className="library-controls">
          <input
            type="text"
            placeholder="Search your library..."
            className="library-search"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
          
          <div className="library-filters">
            <select value={filterType} onChange={(e) => setFilterType(e.target.value as FilterType)}>
              <option value="all">All Papers</option>
              <option value="open-access">Open Access Only</option>
              <option value="recent">Recently Added</option>
            </select>

            <select value={selectedYear || ''} onChange={(e) => setSelectedYear(e.target.value ? Number(e.target.value) : null)}>
              <option value="">All Years</option>
              {availableYears.map(year => year ? (
                <option key={year} value={year}>{year}</option>
              ) : null)}
            </select>

            <select value={sortType} onChange={(e) => setSortType(e.target.value as SortType)}>
              <option value="saved-desc">Recently Saved</option>
              <option value="saved-asc">Oldest First</option>
              <option value="citations-desc">Most Cited</option>
              <option value="year-desc">Newest Published</option>
            </select>
          </div>
        </div>

        <div className="content-grid">
          {loading ? (
            <div className="library-loading">
              <div className="loading-spinner"></div>
              <p>Loading your library...</p>
            </div>
          ) : filteredPapers.length > 0 ? (
            <div className={`papers-${viewMode}`}>
              {filteredPapers.map((paper) => (
                <div key={paper.id} className="library-paper-card">
                  <div className="paper-header">
                    <h3>
                      <a href={paper.doi ? `https://doi.org/${paper.doi}` : '#'} target="_blank" rel="noopener noreferrer">
                        {paper.title}
                      </a>
                    </h3>
                    {paper.is_open_access && <span className="oa-badge">OA</span>}
                  </div>

                  <p className="paper-authors">
                    {paper.authors.slice(0, 5).join(', ')}
                    {paper.authors.length > 5 ? ', et al.' : ''}
                  </p>

                  <div className="paper-meta">
                    {paper.venue && <span className="venue">{paper.venue}</span>}
                    {paper.year && <span>{paper.year}</span>}
                    <span className="citations">📊 {paper.cited_by_count} citations</span>
                  </div>

                  {paper.abstract && (
                    <p className="paper-abstract">
                      {paper.abstract.length > 300 
                        ? paper.abstract.substring(0, 300) + '...' 
                        : paper.abstract}
                    </p>
                  )}

                  {paper.concepts.length > 0 && (
                    <div className="paper-concepts">
                      {paper.concepts.slice(0, 5).map((concept, i) => (
                        <span key={i} className="concept-tag">{concept}</span>
                      ))}
                    </div>
                  )}

                  <div className="paper-actions">
                    {paper.pdf_url && (
                      <a href={paper.pdf_url} target="_blank" rel="noopener noreferrer" className="action-btn">
                        📄 PDF
                      </a>
                    )}
                    <button onClick={() => copyCitation(paper)} className="action-btn">
                      � Cite
                    </button>
                    <button onClick={() => deletePaper(paper.id)} className="action-btn delete-btn">
                      🗑️ Remove
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="library-empty">
              <svg viewBox="0 0 24 24" fill="none" width="64" height="64">
                <path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="currentColor" strokeWidth="2"/>
                <path d="M2 17L12 22L22 17" stroke="currentColor" strokeWidth="2"/>
                <path d="M2 12L12 17L22 12" stroke="currentColor" strokeWidth="2"/>
              </svg>
              <h3>No Papers Found</h3>
              <p>
                {searchQuery || filterType !== 'all' || selectedYear 
                  ? 'Try adjusting your filters' 
                  : 'Start saving papers from search results'}
              </p>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
