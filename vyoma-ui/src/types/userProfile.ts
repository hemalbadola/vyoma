export type VyomaUserProfile = {
  uid: string
  username: string
  displayName: string
  tagline: string
  weeklyFocusGoalMinutes: number
  currentIntention: string | null
  intentionSetAt: Date | null
  createdAt: Date
  timezone: string
  activeTasks: string[]
  lastSeenAt: Date | null
}

export type VyomaTask = {
  id: string
  title: string
  description?: string
  project?: string
  deadline: Date | null
  completed: boolean
  focusMinutes: number
  priority: string
}
