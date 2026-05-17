import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import Sidebar from '../components/Sidebar';
import VyomaConsole from '../components/VyomaConsole';
import { type Activity, type PaperStats, type CollectionStats, type CitationStats } from '../services/api';
import './Dashboard.css';

export default function Dashboard() {
  const { user } = useAuth();
  const navigate = useNavigate();
  
  // API Data State
  const [paperStats, setPaperStats] = useState<PaperStats | null>(null);
  const [collectionStats, setCollectionStats] = useState<CollectionStats | null>(null);
  const [citationStats, setCitationStats] = useState<CitationStats | null>(null);
  const [recentActivity, setRecentActivity] = useState<Activity[]>([]);
  const [loading, setLoading] = useState(true);

  // Fetch dashboard data
  useEffect(() => {
    if (!user) return;

    // Mock data for showcase
    setPaperStats({
      total_papers: 12,
      papers_by_year: { '2023': 5, '2024': 7 },
      top_venues: [
        { venue: 'NeurIPS', count: 4 },
        { venue: 'ICML', count: 3 },
      ],
      recent_papers: 3,
    });

    setCollectionStats({
      total_collections: 4,
      total_papers_in_collections: 8,
      public_collections: 1,
      private_collections: 3,
      most_used_collection: {
        id: 1,
        name: 'Machine Learning',
        paper_count: 5,
      },
    });

    setCitationStats({
      total_citations: 15,
      unique_papers: 8,
      average_citations_per_paper: 1.9,
      most_cited_paper: {
        paper_id: '1',
        citation_count: 5,
      },
    });

    setRecentActivity([
      {
        id: 1,
        user_id: 1,
        activity_type: 'paper_added',
        description: 'Added paper: BERT - Pre-training of Deep Bidirectional Transformers',
        created_at: new Date().toISOString(),
      },
      {
        id: 2,
        user_id: 1,
        activity_type: 'collection_created',
        description: 'Created collection: Deep Learning Papers',
        created_at: new Date(Date.now() - 3600000).toISOString(),
      },
    ]);

    setLoading(false);
  }, [user]);

  if (!user) return null;

  const displayName = user.displayName || user.email?.split('@')[0] || 'Researcher';

  return (
    <div className="dashboard-wrapper">
      {/* Animated Background */}
      <div className="dashboard-bg">
        <div className="bg-gradient"></div>
        <div className="bg-grid"></div>
      </div>

      <Sidebar user={user} />

      {/* Main Content */}
      <main className="main-content">
        <header className="main-header">
          <div>
            <h2 className="welcome-text">Welcome back, <span className="highlight">{displayName}</span></h2>
            <p className="subtitle-text">Continue exploring the research universe</p>
          </div>
          
          <button 
            className="action-btn"
            onClick={() => navigate('/scholar-search')}
          >
            <svg viewBox="0 0 24 24" fill="none">
              <circle cx="11" cy="11" r="8" stroke="currentColor" strokeWidth="2"/>
              <path d="M21 21L16.65 16.65" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
            </svg>
            <span>Advanced Search</span>
          </button>
        </header>
        
        {/* Quick Search Bar */}
        <div className="quick-search">
          <form onSubmit={(e) => {
            e.preventDefault();
            const formData = new FormData(e.currentTarget);
            const query = formData.get('search') as string;
            if (query.trim()) {
              navigate(`/scholar-search?q=${encodeURIComponent(query)}`);
            }
          }}>
            <div className="search-box">
              <svg viewBox="0 0 24 24" fill="none" width="20" height="20">
                <circle cx="11" cy="11" r="8" stroke="currentColor" strokeWidth="2"/>
                <path d="M21 21L16.65 16.65" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              </svg>
              <input
                type="text"
                name="search"
                placeholder="Search for papers, authors, topics..."
                className="search-input"
              />
              <button type="submit" className="search-btn">Search</button>
            </div>
          </form>
        </div>

        <div className="content-grid">
          {/* Quick Stats */}
          <section className="quick-stats">
            <div className="stat-item">
              <div className="stat-icon-wrapper purple">
                <svg viewBox="0 0 24 24" fill="none">
                  <path d="M19 21L12 16L5 21V5C5 4.46957 5.21071 3.96086 5.58579 3.58579C5.96086 3.21071 6.46957 3 7 3H17C17.5304 3 18.0391 3.21071 18.4142 3.58579C18.7893 3.96086 19 4.46957 19 5V21Z" stroke="currentColor" strokeWidth="2"/>
                </svg>
              </div>
              <div className="stat-info">
                <p className="stat-label">Total Papers</p>
                <p className="stat-value">
                  {loading ? '...' : paperStats?.total_papers ?? 0}
                </p>
              </div>
            </div>

            <div className="stat-item">
              <div className="stat-icon-wrapper blue">
                <svg viewBox="0 0 24 24" fill="none">
                  <path d="M10 13C10.4295 13.5741 10.9774 14.0492 11.6066 14.3929C12.2357 14.7367 12.9315 14.9411 13.6467 14.9923C14.3618 15.0435 15.0796 14.9404 15.7513 14.6898C16.4231 14.4392 17.0331 14.0471 17.54 13.54L20.54 10.54C21.4508 9.59699 21.9548 8.33397 21.9434 7.02299C21.932 5.71201 21.4061 4.45794 20.4791 3.53091C19.5521 2.60389 18.298 2.07802 16.987 2.06663C15.676 2.05523 14.413 2.55921 13.47 3.47L11.75 5.18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M14 11C13.5705 10.4259 13.0226 9.95084 12.3934 9.60707C11.7642 9.26331 11.0685 9.05886 10.3533 9.00765C9.63819 8.95643 8.92037 9.05961 8.24861 9.3102C7.57685 9.56079 6.96689 9.95289 6.45996 10.46L3.45996 13.46C2.54917 14.403 2.04519 15.666 2.05659 16.977C2.06798 18.288 2.59385 19.5421 3.52087 20.4691C4.4479 21.3961 5.70197 21.922 7.01295 21.9334C8.32393 21.9448 9.58694 21.4408 10.53 20.53L12.24 18.82" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <div className="stat-info">
                <p className="stat-label">Citations</p>
                <p className="stat-value">
                  {loading ? '...' : citationStats?.total_citations ?? 0}
                </p>
              </div>
            </div>

            <div className="stat-item">
              <div className="stat-icon-wrapper green">
                <svg viewBox="0 0 24 24" fill="none">
                  <path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M2 17L12 22L22 17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M2 12L12 17L22 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <div className="stat-info">
                <p className="stat-label">Collections</p>
                <p className="stat-value">
                  {loading ? '...' : collectionStats?.total_collections ?? 0}
                </p>
              </div>
            </div>

            <div className="stat-item">
              <div className="stat-icon-wrapper orange">
                <svg viewBox="0 0 24 24" fill="none">
                  <path d="M9.663 17H4.5C3 17 3 16 3 15C3 11.5 5 10.5 6 10C5 9.66667 3 8.5 3 6C3 4 4.5 2 6.5 2C8.5 2 10 3.5 10 5C10 6.5 9 7.66667 8 8C9 8.5 11 9.5 11 12.5V17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M14.337 17H19.5C21 17 21 16 21 15C21 11.5 19 10.5 18 10C19 9.66667 21 8.5 21 6C21 4 19.5 2 17.5 2C15.5 2 14 3.5 14 5C14 6.5 15 7.66667 16 8C15 8.5 13 9.5 13 12.5V17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <div className="stat-info">
                <p className="stat-label">Papers in Collections</p>
                <p className="stat-value">
                  {loading ? '...' : collectionStats?.total_papers_in_collections ?? 0}
                </p>
              </div>
            </div>
          </section>

          {/* Feature Cards - Quick Access to All Features */}
          <section className="features-section">
            <h3 style={{ color: 'white', marginBottom: '1.5rem', fontSize: '1.25rem' }}>Quick Access</h3>
            <div className="features-grid">
              <div className="feature-card" onClick={() => navigate('/scholar-search')}>
                <div className="feature-icon search-icon">
                  <svg viewBox="0 0 24 24" fill="none">
                    <circle cx="11" cy="11" r="8" stroke="currentColor" strokeWidth="2"/>
                    <path d="M21 21L16.65 16.65" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                  </svg>
                </div>
                <h4>Search Papers</h4>
                <p>Find research papers from 269M+ open access works</p>
                <span className="feature-action">Start Searching →</span>
              </div>

              <div className="feature-card" onClick={() => navigate('/library')}>
                <div className="feature-icon library-icon">
                  <svg viewBox="0 0 24 24" fill="none">
                    <path d="M19 21L12 16L5 21V5C5 4.46957 5.21071 3.96086 5.58579 3.58579C5.96086 3.21071 6.46957 3 7 3H17C17.5304 3 18.0391 3.21071 18.4142 3.58579C18.7893 3.96086 19 4.46957 19 5V21Z" stroke="currentColor" strokeWidth="2"/>
                  </svg>
                </div>
                <h4>My Library</h4>
                <p>Manage saved papers and organize collections</p>
                <span className="feature-action">Open Library →</span>
              </div>

              <div className="feature-card" onClick={() => navigate('/network')}>
                <div className="feature-icon network-icon">
                  <svg viewBox="0 0 24 24" fill="none">
                    <circle cx="18" cy="5" r="3" stroke="currentColor" strokeWidth="2"/>
                    <circle cx="6" cy="12" r="3" stroke="currentColor" strokeWidth="2"/>
                    <circle cx="18" cy="19" r="3" stroke="currentColor" strokeWidth="2"/>
                    <path d="M8.59 13.51L15.42 17.49M15.41 6.51L8.59 10.49" stroke="currentColor" strokeWidth="2"/>
                  </svg>
                </div>
                <h4>Citation Network</h4>
                <p>Visualize connections between research papers</p>
                <span className="feature-action">View Network →</span>
              </div>

              <div className="feature-card" onClick={() => navigate('/mentor')}>
                <div className="feature-icon mentor-icon">
                  <svg viewBox="0 0 24 24" fill="none">
                    <path d="M17 21V19C17 17.9391 16.5786 16.9217 15.8284 16.1716C15.0783 15.4214 14.0609 15 13 15H5C3.93913 15 2.92172 15.4214 2.17157 16.1716C1.42143 16.9217 1 17.9391 1 19V21" stroke="currentColor" strokeWidth="2"/>
                    <circle cx="9" cy="7" r="4" stroke="currentColor" strokeWidth="2"/>
                    <path d="M23 21V19C22.9993 18.1137 22.7044 17.2528 22.1614 16.5523C21.6184 15.8519 20.8581 15.3516 20 15.13M16 3.13C16.8604 3.35031 17.623 3.85071 18.1676 4.55232C18.7122 5.25392 19.0078 6.11683 19.0078 7.005C19.0078 7.89318 18.7122 8.75608 18.1676 9.45769C17.623 10.1593 16.8604 10.6597 16 10.88" stroke="currentColor" strokeWidth="2"/>
                  </svg>
                </div>
                <h4>Mentor Dashboard</h4>
                <p>Track student progress and research activity</p>
                <span className="feature-action">View Students →</span>
              </div>

              <div className="feature-card" onClick={() => navigate('/chat')}>
                <div className="feature-icon chat-icon">
                  <svg viewBox="0 0 24 24" fill="none">
                    <path d="M21 15C21 15.5304 20.7893 16.0391 20.4142 16.4142C20.0391 16.7893 19.5304 17 19 17H7L3 21V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H19C19.5304 3 20.0391 3.21071 20.4142 3.58579C20.7893 3.96086 21 4.46957 21 5V15Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </div>
                <h4>AI Chat</h4>
                <p>Ask questions and get research assistance</p>
                <span className="feature-action">Start Chat →</span>
              </div>
            </div>
          </section>

          {/* Vyoma Console */}
          <section className="vyoma-console-section">
            <VyomaConsole />
          </section>

          {/* Recent Activity */}
          <section className="activity-card">
            <div className="card-header">
              <h3>Recent Activity</h3>
              <button className="view-all">View all</button>
            </div>
            {loading ? (
              <div className="activity-empty">
                <p>Loading activity...</p>
              </div>
            ) : recentActivity.length > 0 ? (
              <div className="activity-list">
                {recentActivity.slice(0, 5).map((activity) => (
                  <div key={activity.id} className="activity-item">
                    <div className="activity-icon">
                      {activity.activity_type === 'paper_added' && '📄'}
                      {activity.activity_type === 'collection_created' && '📚'}
                      {activity.activity_type === 'citation_added' && '🔗'}
                      {activity.activity_type === 'search_performed' && '🔍'}
                      {!['paper_added', 'collection_created', 'citation_added', 'search_performed'].includes(activity.activity_type) && '✨'}
                    </div>
                    <div className="activity-content">
                      <p className="activity-description">{activity.description}</p>
                      <p className="activity-time">
                        {new Date(activity.created_at).toLocaleString()}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="activity-empty">
                <svg viewBox="0 0 24 24" fill="none">
                  <path d="M9 11L12 14L22 4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M21 12V19C21 19.5304 20.7893 20.0391 20.4142 20.4142C20.0391 20.7893 19.5304 21 19 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H16" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
                <p>No recent activity</p>
                <span>Start by exploring papers or creating a new research project</span>
              </div>
            )}
          </section>

          {/* Recommended Papers */}
          <section className="recommended-card">
            <div className="card-header">
              <h3>Recommended for You</h3>
              <button className="refresh-btn">
                <svg viewBox="0 0 24 24" fill="none">
                  <path d="M1 4V10H7M23 20V14H17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M20.49 9C19.9828 7.56678 19.1209 6.28536 17.9845 5.27541C16.8482 4.26546 15.4745 3.5596 13.9917 3.22422C12.5089 2.88885 10.9652 2.93434 9.50481 3.35677C8.04437 3.77921 6.71475 4.56471 5.64 5.64L1 10M23 14L18.36 18.36C17.2853 19.4353 15.9556 20.2208 14.4952 20.6432C13.0348 21.0657 11.4911 21.1111 10.0083 20.7758C8.52547 20.4404 7.1518 19.7346 6.01547 18.7246C4.87913 17.7146 4.01717 16.4332 3.51 15" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
            <div className="activity-empty">
              <svg viewBox="0 0 24 24" fill="none">
                <path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M2 17L12 22L22 17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M2 12L12 17L22 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              <p>No recommendations yet</p>
              <span>Save papers to get personalized recommendations</span>
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}
