export function SentinelAnimation() {
  return (
    <div className="pillar-canvas pillar-canvas--sentinel" aria-hidden="true">
      <svg viewBox="0 0 120 120" className="sentinel-svg">
        <circle cx="60" cy="60" r="44" className="sentinel-track" />
        <circle cx="60" cy="60" r="44" className="sentinel-arc" pathLength="1" />
        <circle cx="60" cy="60" r="6" className="sentinel-pulse" />
      </svg>
      <p className="sentinel-task-label">Project draft · due 3pm</p>
    </div>
  )
}

export function CalendarMindAnimation() {
  return (
    <div className="pillar-canvas pillar-canvas--calendar" aria-hidden="true">
      <div className="calendar-day">
        <span className="calendar-block calendar-block--meeting" />
        <span className="calendar-block calendar-block--meeting" />
        <span className="calendar-block calendar-block--gap calendar-block--wrong" />
        <span className="calendar-block calendar-block--meeting" />
        <span className="calendar-block calendar-block--gap calendar-block--right">
          <span className="calendar-focus-block" />
        </span>
      </div>
    </div>
  )
}

export function AmbientLayerAnimation() {
  const lines = [
    'Current: Project draft · 2h 15m',
    'Next: Stand-up in 22 min',
    'Focus session active · 47 min',
  ]

  return (
    <div className="pillar-canvas pillar-canvas--ambient" aria-hidden="true">
      <div className="ambient-bar">
        <div className="ambient-text-stack">
          {lines.map((line) => (
            <span key={line} className="ambient-line">
              {line}
            </span>
          ))}
        </div>
      </div>
    </div>
  )
}
