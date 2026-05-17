import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { useUserProfile } from '../contexts/UserProfileContext'
import VyomaAppLayout from '../layouts/VyomaAppLayout'
import { fetchUserTasks } from '../services/userProfile'
import type { VyomaTask } from '../types/userProfile'

function formatDeadline(date: Date | null): string {
  if (!date) return 'No deadline'
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function focusHours(minutes: number): string {
  return `${(minutes / 60).toFixed(1)}h`
}

export default function Dashboard() {
  const { user } = useAuth()
  const { profile, loading: profileLoading } = useUserProfile()
  const [tasks, setTasks] = useState<VyomaTask[]>([])
  const [tasksLoading, setTasksLoading] = useState(true)

  useEffect(() => {
    if (!user?.uid) return
    let cancelled = false
    setTasksLoading(true)
    fetchUserTasks(user.uid)
      .then((list) => {
        if (!cancelled) setTasks(list)
      })
      .catch(() => {
        if (!cancelled) setTasks([])
      })
      .finally(() => {
        if (!cancelled) setTasksLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [user?.uid])

  if (!user || profileLoading) return null

  const displayName = profile?.displayName || user.displayName || 'Operator'
  const openTasks = tasks.filter((t) => !t.completed)
  const dueSoon = openTasks.filter((t) => t.deadline).slice(0, 5)
  const weeklyGoal = profile?.weeklyFocusGoalMinutes ?? 600
  const focusThisWeek = tasks.reduce((sum, t) => sum + t.focusMinutes, 0)

  return (
    <VyomaAppLayout>
      <header className="vyoma-page-header">
        <p className="vyoma-page-eyebrow">War Room</p>
        <h1 className="vyoma-page-title">
          Welcome, <span className="accent">{displayName}</span>
        </h1>
        <p className="vyoma-page-sub">
          {profile?.tagline || 'The intelligence between your plans and your time.'}
          {profile?.username ? ` · @${profile.username}` : ''}
        </p>
      </header>

      <div className="vyoma-stat-grid">
        <div className="vyoma-stat-card">
          <p className="vyoma-stat-label">Open tasks</p>
          <p className="vyoma-stat-value">{tasksLoading ? '…' : openTasks.length}</p>
        </div>
        <div className="vyoma-stat-card">
          <p className="vyoma-stat-label">Focus logged</p>
          <p className="vyoma-stat-value">
            {focusHours(focusThisWeek)} / {focusHours(weeklyGoal)}
          </p>
        </div>
        <div className="vyoma-stat-card">
          <p className="vyoma-stat-label">Timezone</p>
          <p className="vyoma-stat-value" style={{ fontSize: '1rem' }}>
            {profile?.timezone ?? '—'}
          </p>
        </div>
      </div>

      <div className="vyoma-grid-2">
        <section className="vyoma-glass-card">
          <h2 className="vyoma-card-title">Today&apos;s intention</h2>
          {profile?.currentIntention ? (
            <p className="vyoma-intention">{profile.currentIntention}</p>
          ) : (
            <p className="vyoma-empty" style={{ padding: '1rem 0' }}>
              No intention set yet — open the Vyoma app to broadcast your focus for the day.
            </p>
          )}
          {profile?.intentionSetAt && (
            <p className="vyoma-meta-line">
              Updated {profile.intentionSetAt.toLocaleString()}
            </p>
          )}
        </section>

        <section className="vyoma-glass-card vyoma-terminal-card">
          <h2 className="vyoma-card-title">Morning briefing</h2>
          <pre className="vyoma-terminal-snippet">{`08:00 AM  ↳ Syncing calendar…
        ↳ Reading your task board…
        ↳ Finding focus windows

08:01 AM  ↳ Your day is ready.`}</pre>
        </section>
      </div>

      <section className="vyoma-glass-card" style={{ marginTop: '1.25rem' }}>
        <div className="vyoma-card-head-row">
          <h2 className="vyoma-card-title">Your tasks</h2>
          <span className="vyoma-meta-line">From Firestore · same as mobile</span>
        </div>

        {tasksLoading ? (
          <p className="vyoma-empty">Loading tasks…</p>
        ) : dueSoon.length > 0 ? (
          <ul className="vyoma-task-list">
            {dueSoon.map((task) => (
              <li
                key={task.id}
                className={`vyoma-task-item${task.completed ? ' vyoma-task-item--done' : ''}`}
              >
                <div>
                  <p className="vyoma-task-title">{task.title}</p>
                  {task.project && <p className="vyoma-meta-line">{task.project}</p>}
                </div>
                <span className={`vyoma-task-meta${task.priority === 'high' ? ' vyoma-priority-high' : ''}`}>
                  {formatDeadline(task.deadline)}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="vyoma-empty">
            No tasks in the cloud yet. Add tasks in the Vyoma mobile app — they appear here automatically.
          </p>
        )}

        {profile?.activeTasks && profile.activeTasks.length > 0 && (
          <div className="vyoma-active-chips">
            <p className="vyoma-meta-line">Active on profile</p>
            <div className="vyoma-chips">
              {profile.activeTasks.map((title) => (
                <span key={title} className="vyoma-chip">
                  {title}
                </span>
              ))}
            </div>
          </div>
        )}
      </section>

      <section className="vyoma-quick-links">
        <Link to="/chat" className="vyoma-quick-link">
          <span>Ask Vyoma</span>
          <small>Operator chat</small>
        </Link>
        <Link to="/feature-stack" className="vyoma-quick-link">
          <span>Systems</span>
          <small>Sentinel · Calendar · Ambient</small>
        </Link>
      </section>
    </VyomaAppLayout>
  )
}
