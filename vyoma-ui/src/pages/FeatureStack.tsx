import VyomaAppLayout from '../layouts/VyomaAppLayout'
import './FeatureStack.css'

export default function FeatureStack() {
  const features = [
    {
      id: 'sentinel',
      title: 'The Sentinel',
      description: 'Watches every deadline. Knows when a window is closing before you feel the pressure.',
      status: 'Active',
      metric: 'Real-time',
    },
    {
      id: 'calendar',
      title: 'Calendar Mind',
      description: 'Reads the shape of your day. Finds the real gaps. Protects the time that matters.',
      status: 'Active',
      metric: 'Sub-second',
    },
    {
      id: 'ambient',
      title: 'Ambient Layer',
      description: 'On your lock screen. In your notifications. Everywhere you already look.',
      status: 'Beta',
      metric: 'Mobile',
    },
    {
      id: 'core',
      title: 'Vyoma Core',
      description: 'The intelligence between your plans and your time.',
      status: 'Active',
      metric: 'vyoma-in',
    },
  ]

  return (
    <VyomaAppLayout>
      <header className="vyoma-page-header">
        <p className="vyoma-page-eyebrow">Infrastructure</p>
        <h1 className="vyoma-page-title">Vyoma systems</h1>
        <p className="vyoma-page-sub">The three pillars that power your War Room — same stack as the mobile app.</p>
      </header>

      <section className="featurestack-content">
        <div className="vyoma-glass-card vyoma-table-wrapper">
          <table className="vyoma-table">
            <thead>
              <tr>
                <th>Component</th>
                <th>Description</th>
                <th>Status</th>
                <th>Telemetry</th>
              </tr>
            </thead>
            <tbody>
              {features.map((feature) => (
                <tr key={feature.id} className="vyoma-table-row">
                  <td className="font-semibold text-white">{feature.title}</td>
                  <td className="text-slate-300 text-sm max-w-md">{feature.description}</td>
                  <td>
                    <span className={`status-badge ${feature.status.toLowerCase()}`}>{feature.status}</span>
                  </td>
                  <td className="text-amber-500/80 font-mono text-sm">{feature.metric}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </VyomaAppLayout>
  )
}
