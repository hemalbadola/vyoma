import { useAuth } from '../contexts/AuthContext'
import Sidebar from '../components/Sidebar'
import './FeatureStack.css'

export default function FeatureStack() {
  const { user } = useAuth()

  const features = [
    {
      id: 'core',
      title: 'Vyoma Core',
      description: 'The central intelligence engine that reads the gaps between your meetings, tasks, and deadlines.',
      status: 'Active',
      metric: '99.9% Uptime'
    },
    {
      id: 'sentinel',
      title: 'The Sentinel',
      description: 'Watches every deadline. Knows when a window is closing before you feel the pressure.',
      status: 'Active',
      metric: 'Real-time Tracking'
    },
    {
      id: 'calendar',
      title: 'Calendar Mind',
      description: 'Reads the shape of your day. Finds the real gaps. Protects the time that matters.',
      status: 'Active',
      metric: 'Sub-second Sync'
    },
    {
      id: 'ambient',
      title: 'Ambient Layer',
      description: 'On your lock screen. In your notifications. Everywhere you already look. Always present.',
      status: 'Beta',
      metric: 'iOS / macOS'
    }
  ]

  return (
    <div className="dashboard-wrapper featurestack-page">
      {user && <Sidebar user={user} />}
      <main className="main-content">
        <header className="main-header">
          <div>
            <p className="subtitle-text uppercase tracking-widest text-amber-500/80 text-xs font-bold mb-2">Vyoma Infrastructure</p>
            <h1 className="welcome-text">Feature Stack</h1>
          </div>
          <button className="action-btn vyoma-instrumental-btn">
            System Diagnostics
          </button>
        </header>

        <section className="featurestack-content">
          <div className="glass-panel vyoma-table-wrapper">
            <table className="vyoma-table">
              <thead>
                <tr>
                  <th>Component</th>
                  <th>Description</th>
                  <th>Status</th>
                  <th>Telemetry</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {features.map((feature) => (
                  <tr key={feature.id} className="vyoma-table-row">
                    <td className="font-semibold text-white">{feature.title}</td>
                    <td className="text-slate-300 text-sm max-w-md">{feature.description}</td>
                    <td>
                      <span className={`status-badge ${feature.status.toLowerCase()}`}>
                        {feature.status}
                      </span>
                    </td>
                    <td className="text-amber-500/80 font-mono text-sm">{feature.metric}</td>
                    <td>
                      <button className="vyoma-instrumental-btn-small">Inspect</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="featurestack-cards mt-12 grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="glass-panel text-center flex flex-col hover:border-amber-500/40 transition-colors cursor-pointer">
              <h3 className="text-xl font-bold text-white mb-2">Network Graph</h3>
              <p className="text-slate-400 text-sm mb-6">Visualize the latency across the Vyoma neural lattice.</p>
              <button className="vyoma-instrumental-btn mt-auto mx-auto w-full max-w-xs">Initialize Protocol</button>
            </div>
            
            <div className="glass-panel text-center flex flex-col hover:border-amber-500/40 transition-colors cursor-pointer">
              <h3 className="text-xl font-bold text-white mb-2">Data Governance</h3>
              <p className="text-slate-400 text-sm mb-6">Review access logs and calibrate encryption protocols.</p>
              <button className="vyoma-instrumental-btn mt-auto mx-auto w-full max-w-xs">Audit Logs</button>
            </div>
          </div>
        </section>
      </main>
    </div>
  )
}
