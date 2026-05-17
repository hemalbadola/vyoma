import { useAuth } from '../contexts/AuthContext'
import Sidebar from '../components/Sidebar.tsx'
import VyomaConsole from '../components/VyomaConsole'
import './Search.css'

export default function Search() {
  const { user } = useAuth()

  if (!user) return null

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
            <h2 className="welcome-text">Search Research Papers</h2>
            <p className="subtitle-text">Explore 269M+ papers with AI-powered search</p>
          </div>
        </header>

        <div className="content-grid">
          <section className="full-width-section">
            <VyomaConsole />
          </section>
        </div>
      </main>
    </div>
  )
}
