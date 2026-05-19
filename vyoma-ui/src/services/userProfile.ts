import {
  collection,
  doc,
  getDocs,
  limit,
  onSnapshot,
  query,
  serverTimestamp,
  writeBatch,
  type DocumentData,
  type Unsubscribe,
} from 'firebase/firestore'
import { auth, db } from '../firebase'
import type { VyomaTask, VyomaUserProfile } from '../types/userProfile'

function tsToDate(value: unknown): Date | null {
  if (!value || typeof value !== 'object' || !('toDate' in value)) return null
  return (value as { toDate: () => Date }).toDate()
}

export function mapUserProfile(uid: string, data: DocumentData): VyomaUserProfile {
  return {
    uid,
    username: String(data.username ?? ''),
    displayName: String(data.displayName ?? ''),
    tagline: String(data.tagline ?? ''),
    weeklyFocusGoalMinutes: Number(data.weeklyFocusGoalMinutes ?? 600),
    currentIntention: data.currentIntention ? String(data.currentIntention) : null,
    intentionSetAt: tsToDate(data.intentionSetAt),
    createdAt: tsToDate(data.createdAt) ?? new Date(),
    timezone: String(data.timezone ?? 'UTC'),
    activeTasks: Array.isArray(data.activeTasks) ? data.activeTasks.map(String) : [],
    lastSeenAt: tsToDate(data.lastSeenAt),
    subscriptionPlan: data.subscriptionPlan ? String(data.subscriptionPlan) : null,
    subscriptionStatus: data.subscriptionStatus ? String(data.subscriptionStatus) : null,
    subscriptionExpiresAt: tsToDate(data.subscriptionExpiresAt),
  }
}

export function subscribeUserProfile(
  uid: string,
  onData: (profile: VyomaUserProfile | null) => void,
  onError?: (error: Error) => void
): Unsubscribe {
  return onSnapshot(
    doc(db, 'users', uid),
    (snap) => {
      if (!snap.exists()) {
        onData(null)
        return
      }
      onData(mapUserProfile(snap.id, snap.data()))
    },
    (err) => onError?.(err)
  )
}

export async function createUserProfile(input: {
  username: string
  tagline: string
  displayName?: string
}): Promise<void> {
  const user = auth.currentUser
  if (!user) throw new Error('Not signed in')

  const cleanUsername = input.username.trim()
  if (cleanUsername.length < 3) throw new Error('Username must be at least 3 characters')

  const usernameLower = cleanUsername.toLowerCase()
  const usernameRef = doc(db, 'usernames', usernameLower)
  const userRef = doc(db, 'users', user.uid)

  const batch = writeBatch(db)
  batch.set(usernameRef, { uid: user.uid, createdAt: serverTimestamp() })
  batch.set(userRef, {
    uid: user.uid,
    username: cleanUsername,
    username_lower: usernameLower,
    displayName: input.displayName?.trim() || user.displayName || cleanUsername,
    tagline: input.tagline.trim(),
    weeklyFocusGoalMinutes: 600,
    createdAt: serverTimestamp(),
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
    activeTasks: [],
    shareTasksWithFriends: true,
    showOnlineStatus: true,
    enableTelemetry: true,
    shareIntention: true,
    lastSeenAt: serverTimestamp(),
  })

  await batch.commit()
}

export async function fetchUserTasks(uid: string, max = 8): Promise<VyomaTask[]> {
  const snap = await getDocs(query(collection(db, 'users', uid, 'tasks'), limit(max)))
  const tasks: VyomaTask[] = []

  snap.forEach((docSnap) => {
    const data = docSnap.data()
    tasks.push({
      id: docSnap.id,
      title: String(data.title ?? 'Untitled'),
      description: data.description ? String(data.description) : undefined,
      project: data.project ? String(data.project) : undefined,
      deadline: tsToDate(data.deadline) ?? (typeof data.deadline === 'string' ? new Date(data.deadline) : null),
      completed: Boolean(data.completed),
      focusMinutes: Number(data.focusMinutes ?? 0),
      priority: String(data.priority ?? 'normal'),
    })
  })

  return tasks.sort((a, b) => {
    if (a.completed !== b.completed) return a.completed ? 1 : -1
    if (a.deadline && b.deadline) return a.deadline.getTime() - b.deadline.getTime()
    if (a.deadline) return -1
    if (b.deadline) return 1
    return a.title.localeCompare(b.title)
  })
}
