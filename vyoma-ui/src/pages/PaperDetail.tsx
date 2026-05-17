import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import Sidebar from '../components/Sidebar';
import { fetchFromOpenAlex } from '../config/openalex';
import './PaperDetail.css';

interface Author {
  id: string | null;
  name: string;
  institution: string | null;
}

interface Concept {
  id: string;
  display_name: string;
  score: number;
}

interface Paper {
  id: string;
  title: string;
  authors: Author[];
  publication_year: number | null;
  publication_date: string | null;
  venue: string | null;
  cited_by_count: number;
  doi: string | null;
  pdf_url: string | null;
  abstract: string | null;
  is_open_access: boolean;
  concepts: Concept[];
  referenced_works: string[];
  related_works: string[];
}

interface RelatedPaper {
  id: string;
  title: string;
  authors: string[];
  year: number | null;
  cited_by_count: number;
}

export default function PaperDetail() {
  const { id } = useParams<{ id: string }>();
  const { user, loading: authLoading, getApiToken } = useAuth();
  const navigate = useNavigate();
  
  const [paper, setPaper] = useState<Paper | null>(null);
  const [relatedPapers, setRelatedPapers] = useState<RelatedPaper[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showFullAbstract, setShowFullAbstract] = useState(false);
  const [isSaved, setIsSaved] = useState(false);
  const [savingPaper, setSavingPaper] = useState(false);

  useEffect(() => {
    if (authLoading) return;
    
    if (!user) {
      navigate('/login');
      return;
    }

    fetchPaperDetails();
  }, [id, user, authLoading, navigate]);

  const fetchPaperDetails = async () => {
    if (!id) return;

    try {
      setLoading(true);
      setError(null);

      // Fetch paper details from OpenAlex Walden API with expanded content
      const response = await fetchFromOpenAlex(`/works/${id}`);
      
      if (!response.ok) {
        throw new Error('Paper not found');
      }

      const data = await response.json();
      
      const paperData: Paper = {
        id: data.id,
        title: data.title || 'Untitled',
        authors: data.authorships?.map((a: any) => ({
          id: a.author?.id || null,
          name: a.author?.display_name || 'Unknown',
          institution: a.institutions?.[0]?.display_name || null,
        })) || [],
        publication_year: data.publication_year,
        publication_date: data.publication_date,
        venue: data.primary_location?.source?.display_name || data.host_venue?.display_name || null,
        cited_by_count: data.cited_by_count || 0,
        doi: data.doi,
        pdf_url: data.open_access?.oa_url || data.primary_location?.pdf_url || null,
        abstract: data.abstract_inverted_index ? reconstructAbstract(data.abstract_inverted_index) : null,
        is_open_access: data.open_access?.is_oa || false,
        concepts: data.concepts?.slice(0, 8).map((c: any) => ({
          id: c.id,
          display_name: c.display_name,
          score: c.score,
        })) || [],
        referenced_works: data.referenced_works || [],
        related_works: data.related_works || [],
      };

      setPaper(paperData);

      // Check if paper is already saved
      if (user) {
        checkIfSaved(id);
      }

      // Fetch related papers
      if (paperData.related_works.length > 0) {
        fetchRelatedPapers(paperData.related_works.slice(0, 5));
      }
    } catch (err) {
      console.error('Error fetching paper:', err);
      setError(err instanceof Error ? err.message : 'Failed to load paper');
    } finally {
      setLoading(false);
    }
  };

  const reconstructAbstract = (invertedIndex: Record<string, number[]>): string => {
    const words: [string, number][] = [];
    for (const [word, positions] of Object.entries(invertedIndex)) {
      positions.forEach(pos => words.push([word, pos]));
    }
    words.sort((a, b) => a[1] - b[1]);
    return words.map(w => w[0]).join(' ');
  };

  const checkIfSaved = async (paperId: string) => {
    if (!user) return;

    try {
      const token = await getApiToken();
      const response = await fetch('https://paperverse-kvw2y.ondigitalocean.app/api/papers/', {
        headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      });

      if (response.ok) {
        const savedPapers = await response.json();
        setIsSaved(savedPapers.some((p: any) => p.id === paperId));
      }
    } catch (err) {
      console.error('Error checking saved status:', err);
    }
  };

  const fetchRelatedPapers = async (workIds: string[]) => {
    try {
      const promises = workIds.map(async (workId) => {
        // Use Walden API with expanded content
        const workIdPath = workId.replace('https://openalex.org/', '');
        const response = await fetchFromOpenAlex(`/works/${workIdPath}`);
        if (response.ok) {
          const data = await response.json();
          return {
            id: data.id,
            title: data.title || 'Untitled',
            authors: data.authorships?.slice(0, 3).map((a: any) => a.author?.display_name || 'Unknown') || [],
            year: data.publication_year,
            cited_by_count: data.cited_by_count || 0,
          };
        }
        return null;
      });

      const results = await Promise.all(promises);
      setRelatedPapers(results.filter((p): p is RelatedPaper => p !== null));
    } catch (err) {
      console.error('Error fetching related papers:', err);
    }
  };

  const savePaper = async () => {
    if (!user || !paper || savingPaper) return;

    try {
      setSavingPaper(true);
      const token = await getApiToken();

      const response = await fetch('https://paperverse-kvw2y.ondigitalocean.app/api/papers/', {
        method: 'POST',
        headers: {
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          id: paper.id,
          title: paper.title,
          authors: paper.authors.map(a => a.name),
          year: paper.publication_year,
          venue: paper.venue,
          cited_by_count: paper.cited_by_count,
          abstract: paper.abstract,
          doi: paper.doi,
          pdf_url: paper.pdf_url,
          is_open_access: paper.is_open_access,
          concepts: paper.concepts.map(c => c.display_name),
        }),
      });

      if (response.ok || response.status === 409) {
        setIsSaved(true);
        alert('Paper saved to library!');
      } else {
        throw new Error('Failed to save paper');
      }
    } catch (err) {
      console.error('Error saving paper:', err);
      alert('Failed to save paper. Please try again.');
    } finally {
      setSavingPaper(false);
    }
  };

  const copyCitation = () => {
    if (!paper) return;
    
    const authors = paper.authors.slice(0, 3).map(a => a.name).join(', ') + 
                   (paper.authors.length > 3 ? ' et al.' : '');
    const citation = `${authors}. "${paper.title}." ${paper.venue || 'Unknown Venue'}, ${paper.publication_year || 'n.d.'}.`;
    
    navigator.clipboard.writeText(citation);
    alert('Citation copied to clipboard!');
  };

  if (!user) return null;

  if (loading) {
    return (
      <div className="dashboard-wrapper">
        <div className="dashboard-bg">
          <div className="bg-gradient"></div>
          <div className="bg-grid"></div>
        </div>
        <Sidebar user={user} />
        <main className="main-content">
          <div className="loading-container">
            <div className="loading-spinner"></div>
            <p>Loading paper...</p>
          </div>
        </main>
      </div>
    );
  }

  if (error || !paper) {
    return (
      <div className="dashboard-wrapper">
        <div className="dashboard-bg">
          <div className="bg-gradient"></div>
          <div className="bg-grid"></div>
        </div>
        <Sidebar user={user} />
        <main className="main-content">
          <div className="error-container">
            <h2>Paper Not Found</h2>
            <p>{error || 'Unable to load paper details'}</p>
            <button onClick={() => navigate('/scholar-search')} className="action-btn">
              Back to Search
            </button>
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="dashboard-wrapper">
      <div className="dashboard-bg">
        <div className="bg-gradient"></div>
        <div className="bg-grid"></div>
      </div>

      <Sidebar user={user} />

      <main className="main-content paper-detail-main">
        {/* Back Button */}
        <button onClick={() => navigate(-1)} className="back-button">
          <svg viewBox="0 0 24 24" fill="none" width="20" height="20">
            <path d="M19 12H5M12 19l-7-7 7-7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          Back
        </button>

        {/* Paper Header */}
        <div className="paper-header-section">
          <div className="paper-title-row">
            <h1 className="paper-title">{paper.title}</h1>
            {paper.is_open_access && <span className="oa-badge-large">OPEN ACCESS</span>}
          </div>

          <div className="paper-authors-list">
            {paper.authors.map((author, idx) => (
              <span key={idx} className="author-item">
                <strong>{author.name}</strong>
                {author.institution && <span className="institution-name">({author.institution})</span>}
                {idx < paper.authors.length - 1 && ', '}
              </span>
            ))}
          </div>

          <div className="paper-metadata">
            {paper.venue && <span className="meta-item">📚 {paper.venue}</span>}
            {paper.publication_year && <span className="meta-item">📅 {paper.publication_year}</span>}
            <span className="meta-item">📊 {paper.cited_by_count.toLocaleString()} citations</span>
            {paper.doi && (
              <a href={`https://doi.org/${paper.doi}`} target="_blank" rel="noopener noreferrer" className="meta-item meta-link">
                🔗 DOI
              </a>
            )}
          </div>

          {/* Action Buttons */}
          <div className="paper-actions-bar">
            <button onClick={savePaper} disabled={isSaved || savingPaper} className={`action-btn ${isSaved ? 'saved' : ''}`}>
              {isSaved ? '✓ Saved' : savingPaper ? 'Saving...' : '💾 Save to Library'}
            </button>
            <button onClick={copyCitation} className="action-btn">
              📋 Copy Citation
            </button>
            {paper.pdf_url && (
              <a href={paper.pdf_url} target="_blank" rel="noopener noreferrer" className="action-btn">
                📄 View PDF
              </a>
            )}
          </div>
        </div>

        {/* Abstract */}
        {paper.abstract && (
          <div className="paper-section">
            <h2 className="section-title">Abstract</h2>
            <div className="abstract-content">
              <p className={showFullAbstract ? '' : 'abstract-truncated'}>
                {paper.abstract}
              </p>
              {paper.abstract.length > 500 && (
                <button onClick={() => setShowFullAbstract(!showFullAbstract)} className="read-more-btn">
                  {showFullAbstract ? 'Show Less' : 'Read More'}
                </button>
              )}
            </div>
          </div>
        )}

        {/* PDF Viewer */}
        {paper.pdf_url && (
          <div className="paper-section">
            <h2 className="section-title">Document Viewer</h2>
            <div className="pdf-viewer-container">
              <iframe
                src={`${paper.pdf_url}#toolbar=1&navpanes=0&scrollbar=1`}
                title="Paper PDF"
                className="pdf-iframe"
              />
              <div className="pdf-fallback">
                <p>PDF viewer may not work for all papers.</p>
                <a href={paper.pdf_url} target="_blank" rel="noopener noreferrer" className="action-btn">
                  Open PDF in New Tab
                </a>
              </div>
            </div>
          </div>
        )}

        {/* Key Concepts */}
        {paper.concepts.length > 0 && (
          <div className="paper-section">
            <h2 className="section-title">Key Concepts</h2>
            <div className="concepts-grid">
              {paper.concepts.map((concept) => (
                <div key={concept.id} className="concept-badge" style={{ opacity: 0.5 + concept.score * 0.5 }}>
                  {concept.display_name}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Related Papers */}
        {relatedPapers.length > 0 && (
          <div className="paper-section">
            <h2 className="section-title">Related Papers</h2>
            <div className="related-papers-list">
              {relatedPapers.map((relatedPaper) => (
                <div 
                  key={relatedPaper.id} 
                  className="related-paper-card"
                  onClick={() => navigate(`/paper/${encodeURIComponent(relatedPaper.id)}`)}
                >
                  <h3 className="related-paper-title">{relatedPaper.title}</h3>
                  <p className="related-paper-authors">
                    {relatedPaper.authors.join(', ')}
                    {relatedPaper.authors.length > 3 && ' et al.'}
                  </p>
                  <div className="related-paper-meta">
                    {relatedPaper.year && <span>{relatedPaper.year}</span>}
                    <span>📊 {relatedPaper.cited_by_count.toLocaleString()} citations</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Citation Network Preview */}
        <div className="paper-section">
          <h2 className="section-title">Citation Network</h2>
          <div className="network-preview">
            <p>This paper cites {paper.referenced_works.length} works and is cited by {paper.cited_by_count} papers.</p>
            <button onClick={() => navigate('/network')} className="action-btn">
              🕸️ Explore Citation Network
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}
