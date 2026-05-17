import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import './ScholarSearch.css';

interface Author {
  id: string | null;
  name: string;
  institution: string | null;
}

interface Concept {
  id: string;
  name: string;
  score: number;
}

interface Paper {
  id: string;
  title: string;
  authors: Author[];
  publication_date: string | null;
  publication_year: number | null;
  venue: string | null;
  cited_by_count: number;
  doi: string | null;
  pdf_url: string | null;
  abstract: string | null;
  concepts: Concept[];
  open_access: boolean;
}

interface SearchResponse {
  query: string;
  enhanced_query: string | null;
  results: Paper[];
  total_results: number;
  page: number;
  per_page: number;
  total_pages: number;
  search_time_ms: number;
}

const API_URL = 'https://paperverse-kvw2y.ondigitalocean.app';

export default function ScholarSearch() {
  const { user, loading: authLoading, getApiToken } = useAuth();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  
  const [query, setQuery] = useState(searchParams.get('q') || '');
  const [results, setResults] = useState<Paper[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [totalResults, setTotalResults] = useState(0);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [searchTime, setSearchTime] = useState(0);
  const [enhancedQuery, setEnhancedQuery] = useState<string | null>(null);
  
  // Filters
  const [yearFrom, setYearFrom] = useState<string>('');
  const [yearTo, setYearTo] = useState<string>('');
  const [minCitations, setMinCitations] = useState<string>('');
  const [openAccessOnly, setOpenAccessOnly] = useState(false);
  const [sortBy, setSortBy] = useState<'relevance' | 'cited_by_count' | 'publication_date'>('relevance');
  const [showFilters, setShowFilters] = useState(false);
  
  // Saved papers tracking
  const [savedPapers, setSavedPapers] = useState<Set<string>>(new Set());
  
  // PDF loading tracking
  const [loadingPdfs, setLoadingPdfs] = useState<Set<string>>(new Set());

  useEffect(() => {
    const q = searchParams.get('q');
    if (q && q !== query) {
      setQuery(q);
      performSearch(q, 1);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  const performSearch = async (searchQuery: string, pageNum: number) => {
    if (!searchQuery.trim()) return;

    setLoading(true);
    setError(null);

    try {
      const filters: Record<string, string | number | boolean> = {};
      if (yearFrom) filters.year_from = parseInt(yearFrom);
      if (yearTo) filters.year_to = parseInt(yearTo);
      if (minCitations) filters.min_citations = parseInt(minCitations);
      if (openAccessOnly) filters.open_access = true;
      filters.sort_by = sortBy;

      const response = await fetch(`${API_URL}/api/search/search`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: searchQuery,
          page: pageNum,
          per_page: 25,
          use_ai_enhancement: true,
          filters: Object.keys(filters).length > 0 ? filters : undefined,
        }),
      });

      if (!response.ok) throw new Error('Search failed');

      const data: SearchResponse = await response.json();
      setResults(data.results);
      setTotalResults(data.total_results);
      setPage(data.page);
      setTotalPages(data.total_pages);
      setSearchTime(data.search_time_ms);
      setEnhancedQuery(data.enhanced_query);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Search failed');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setSearchParams({ q: query });
    performSearch(query, 1);
  };

  const handlePageChange = (newPage: number) => {
    performSearch(query, newPage);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const savePaper = async (paper: Paper) => {
    if (!user) {
      alert('Please login to save papers');
      return;
    }

    try {
      const token = await getApiToken();
      const response = await fetch(`${API_URL}/api/papers/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          paper_id: paper.id,
          title: paper.title,
          authors: paper.authors.map(a => a.name).join(', '),
          summary: paper.abstract,
          published_year: paper.publication_year,
        }),
      });

      if (response.ok) {
        setSavedPapers(prev => new Set(prev).add(paper.id));
        alert('Paper saved to library!');
      } else if (response.status === 409) {
        alert('Paper already in library');
      } else {
        throw new Error('Failed to save paper');
      }
    } catch {
      alert('Failed to save paper. Please try again.');
    }
  };

  const citePaper = (paper: Paper) => {
    const citation = `${paper.authors.slice(0, 3).map(a => a.name).join(', ')}${paper.authors.length > 3 ? ' et al.' : ''}. "${paper.title}." ${paper.venue || 'Unknown Venue'}, ${paper.publication_year || 'n.d.'}.`;
    
    navigator.clipboard.writeText(citation);
    alert('Citation copied to clipboard!');
  };

  const getPdfUrl = async (paper: Paper) => {
    // If paper already has PDF URL, open it
    if (paper.pdf_url) {
      window.open(paper.pdf_url, '_blank');
      return;
    }

    // Mark as loading
    setLoadingPdfs(prev => new Set(prev).add(paper.id));

    try {
      const params = new URLSearchParams({
        work_id: paper.id,
      });
      if (paper.doi) params.append('doi', paper.doi);

      const response = await fetch(`${API_URL}/api/pdf/get-pdf?${params}`);
      
      if (!response.ok) {
        throw new Error('Failed to get PDF');
      }

      const data = await response.json();
      
      if (data.pdf_url) {
        window.open(data.pdf_url, '_blank');
        
        // Update the paper in results to include the PDF URL
        setResults(prev => prev.map(p => 
          p.id === paper.id ? { ...p, pdf_url: data.pdf_url } : p
        ));
      } else {
        alert(data.error || 'PDF not available for this paper');
      }
    } catch (err) {
      alert('Failed to load PDF. Please try again.');
      console.error('PDF error:', err);
    } finally {
      setLoadingPdfs(prev => {
        const newSet = new Set(prev);
        newSet.delete(paper.id);
        return newSet;
      });
    }
  };

  // Show loading state while checking authentication
  if (authLoading) {
    return (
      <div className="scholar-search">
        <div className="auth-required">
          <h2>Loading...</h2>
          <p>Checking authentication status...</p>
        </div>
      </div>
    );
  }

  // Only redirect to login after we know user is not authenticated
  if (!user) {
    return (
      <div className="scholar-search">
        <div className="auth-required">
          <h2>Please Login</h2>
          <p>You need to be logged in to search papers.</p>
          <button onClick={() => navigate('/login')}>Go to Login</button>
        </div>
      </div>
    );
  }

  return (
    <div className="scholar-search">
      <header className="scholar-header">
        <div className="header-content">
          <h1 className="scholar-logo" onClick={() => navigate('/search')}>
            <span className="logo-paper">Paper</span>
            <span className="logo-verse">Verse</span>
          </h1>
          
          <form className="search-form" onSubmit={handleSearch}>
            <div className="search-box">
              <input
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search articles..."
                className="search-input"
              />
              <button type="submit" className="search-btn">
                <svg viewBox="0 0 24 24" fill="none" width="20" height="20">
                  <circle cx="11" cy="11" r="8" stroke="currentColor" strokeWidth="2"/>
                  <path d="M21 21L16.65 16.65" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                </svg>
              </button>
            </div>
          </form>

          <button className="user-menu" onClick={() => navigate('/dashboard')}>
            <img 
              src={`https://ui-avatars.com/api/?name=${encodeURIComponent(user.displayName || user.email || 'User')}&background=b8860b&color=111`}
              alt="Profile"
            />
          </button>
        </div>

        <div className="search-meta">
          <div className="results-info">
            {totalResults > 0 && (
              <>
                About {totalResults.toLocaleString()} results ({(searchTime / 1000).toFixed(2)}s)
                {enhancedQuery && (
                  <span className="ai-enhanced"> • AI Enhanced Search</span>
                )}
              </>
            )}
          </div>
          
          <div className="search-controls">
            <button 
              className={`filter-toggle ${showFilters ? 'active' : ''}`}
              onClick={() => setShowFilters(!showFilters)}
            >
              <svg viewBox="0 0 24 24" fill="none" width="16" height="16">
                <path d="M3 4h18M3 12h12M3 20h6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              </svg>
              Filters
            </button>

            <select 
              value={sortBy} 
              onChange={(e) => setSortBy(e.target.value as 'relevance' | 'cited_by_count' | 'publication_date')}
              className="sort-select"
            >
              <option value="relevance">Sort by relevance</option>
              <option value="cited_by_count">Sort by citations</option>
              <option value="publication_date">Sort by date</option>
            </select>
          </div>
        </div>

        {showFilters && (
          <div className="filters-panel">
            <div className="filter-group">
              <label>Year Range</label>
              <div className="year-range">
                <input
                  type="number"
                  placeholder="From"
                  value={yearFrom}
                  onChange={(e) => setYearFrom(e.target.value)}
                  min="1900"
                  max="2024"
                />
                <span>—</span>
                <input
                  type="number"
                  placeholder="To"
                  value={yearTo}
                  onChange={(e) => setYearTo(e.target.value)}
                  min="1900"
                  max="2024"
                />
              </div>
            </div>

            <div className="filter-group">
              <label>Min Citations</label>
              <input
                type="number"
                placeholder="0"
                value={minCitations}
                onChange={(e) => setMinCitations(e.target.value)}
                min="0"
              />
            </div>

            <div className="filter-group">
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  checked={openAccessOnly}
                  onChange={(e) => setOpenAccessOnly(e.target.checked)}
                />
                Open Access only
              </label>
            </div>

            <button 
              className="apply-filters"
              onClick={() => performSearch(query, 1)}
            >
              Apply Filters
            </button>
          </div>
        )}
      </header>

      <main className="scholar-results">
        {loading && (
          <div className="loading">
            <div className="spinner"></div>
            <p>Searching 269M+ papers...</p>
          </div>
        )}

        {error && (
          <div className="error-message">
            <p>⚠️ {error}</p>
            <button onClick={() => performSearch(query, page)}>Retry</button>
          </div>
        )}

        {!loading && !error && results.length === 0 && query && (
          <div className="no-results">
            <h3>No results found</h3>
            <p>Try different keywords or check your spelling</p>
          </div>
        )}

        {!loading && results.length > 0 && (
          <div className="results-list">
            {results.map((paper) => (
              <article key={paper.id} className="paper-card">
                <div className="paper-header">
                  <h2 className="paper-title">
                    <a href={paper.pdf_url || `https://openalex.org/${paper.id}`} target="_blank" rel="noopener noreferrer">
                      {paper.title}
                    </a>
                  </h2>
                  {paper.open_access && <span className="oa-badge">Open Access</span>}
                </div>

                <div className="paper-authors">
                  {paper.authors.slice(0, 5).map((author, idx) => (
                    <span key={idx} className="author">
                      {author.name}
                      {author.institution && <span className="institution"> - {author.institution}</span>}
                      {idx < Math.min(4, paper.authors.length - 1) && ', '}
                    </span>
                  ))}
                  {paper.authors.length > 5 && ` ... +${paper.authors.length - 5} more`}
                </div>

                <div className="paper-meta">
                  {paper.venue && <span className="venue">{paper.venue}</span>}
                  {paper.publication_year && <span className="year">{paper.publication_year}</span>}
                  <span className="citations">Cited by {paper.cited_by_count}</span>
                </div>

                {paper.abstract && (
                  <p className="paper-abstract">
                    {paper.abstract.slice(0, 300)}
                    {paper.abstract.length > 300 && '...'}
                  </p>
                )}

                {paper.concepts.length > 0 && (
                  <div className="paper-concepts">
                    {paper.concepts.slice(0, 4).map((concept) => (
                      <span key={concept.id} className="concept-tag">
                        {concept.name}
                      </span>
                    ))}
                  </div>
                )}

                <div className="paper-actions">
                  <button 
                    className={`action-btn ${loadingPdfs.has(paper.id) ? 'loading' : ''}`}
                    onClick={() => getPdfUrl(paper)}
                    disabled={loadingPdfs.has(paper.id)}
                  >
                    <svg viewBox="0 0 24 24" fill="none" width="16" height="16">
                      <path d="M7 18V20H17V18M7 14H17M7 10H17M19 4H5C3.89543 4 3 4.89543 3 6V18C3 19.1046 3.89543 20 5 20H19C20.1046 20 21 19.1046 21 18V6C21 4.89543 20.1046 4 19 4Z" stroke="currentColor" strokeWidth="2"/>
                    </svg>
                    {loadingPdfs.has(paper.id) ? 'Loading...' : paper.pdf_url ? 'View PDF' : 'Get PDF'}
                  </button>
                  
                  <button 
                    className="action-btn primary"
                    onClick={() => navigate('/chat')}
                    title="Chat with this paper using AI"
                  >
                    <svg viewBox="0 0 24 24" fill="none" width="16" height="16">
                      <path d="M8 12H8.01M12 12H12.01M16 12H16.01M21 12C21 16.4183 16.9706 20 12 20C10.4607 20 9.01172 19.6565 7.74467 19.0511L3 20L4.39499 16.28C3.51156 15.0423 3 13.5743 3 12C3 7.58172 7.02944 4 12 4C16.9706 4 21 7.58172 21 12Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                    Chat
                  </button>

                  <button 
                    className={`action-btn ${savedPapers.has(paper.id) ? 'saved' : ''}`}
                    onClick={() => savePaper(paper)}
                  >
                    <svg viewBox="0 0 24 24" fill={savedPapers.has(paper.id) ? 'currentColor' : 'none'} width="16" height="16">
                      <path d="M5 5C5 3.89543 5.89543 3 7 3H17C18.1046 3 19 3.89543 19 5V21L12 17L5 21V5Z" stroke="currentColor" strokeWidth="2"/>
                    </svg>
                    {savedPapers.has(paper.id) ? 'Saved' : 'Save'}
                  </button>

                  <button className="action-btn" onClick={() => citePaper(paper)}>
                    <svg viewBox="0 0 24 24" fill="none" width="16" height="16">
                      <path d="M7 8V6C7 4.34315 8.34315 3 10 3H14C15.6569 3 17 4.34315 17 6V8M3 10H21M5 10L6 20C6 21.1046 6.89543 22 8 22H16C17.1046 22 18 21.1046 18 20L19 10" stroke="currentColor" strokeWidth="2"/>
                    </svg>
                    Cite
                  </button>

                  {paper.doi && (
                    <a 
                      href={`https://doi.org/${paper.doi}`} 
                      target="_blank" 
                      rel="noopener noreferrer"
                      className="action-btn"
                    >
                      DOI
                    </a>
                  )}
                </div>
              </article>
            ))}
          </div>
        )}

        {!loading && totalPages > 1 && (
          <div className="pagination">
            <button
              disabled={page === 1}
              onClick={() => handlePageChange(page - 1)}
              className="page-btn"
            >
              Previous
            </button>

            <div className="page-numbers">
              {Array.from({ length: Math.min(10, totalPages) }, (_, i) => {
                const pageNum = i + 1;
                return (
                  <button
                    key={pageNum}
                    onClick={() => handlePageChange(pageNum)}
                    className={`page-num ${page === pageNum ? 'active' : ''}`}
                  >
                    {pageNum}
                  </button>
                );
              })}
              {totalPages > 10 && <span className="ellipsis">...</span>}
            </div>

            <button
              disabled={page === totalPages}
              onClick={() => handlePageChange(page + 1)}
              className="page-btn"
            >
              Next
            </button>
          </div>
        )}
      </main>
    </div>
  );
}
