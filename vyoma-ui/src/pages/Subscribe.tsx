import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import PaymentModal from '../components/landing/PaymentModal'
import { PRICING_PLANS } from '../config/pricing'
import { useUserProfile } from '../contexts/UserProfileContext'
import { auth } from '../firebase'
import { hasActiveSubscription, subscriptionInactiveReason } from '../lib/subscriptionAccess'

export default function Subscribe() {
  const { profile } = useUserProfile()
  const navigate = useNavigate()
  const plan = PRICING_PLANS[0]

  useEffect(() => {
    if (hasActiveSubscription(profile)) {
      navigate('/dashboard', { replace: true })
    }
  }, [profile, navigate])

  const handleUnlocked = async () => {
    await auth.currentUser?.getIdToken(true)
    navigate('/dashboard', { replace: true })
  }

  return (
    <div className="vyoma-subscribe-page">
      <header className="vyoma-subscribe-page__header">
        <h1>Unlock Vyoma</h1>
        <p>{subscriptionInactiveReason(profile)}</p>
        <button type="button" className="vyoma-subscribe-page__signout" onClick={() => auth.signOut()}>
          Sign out
        </button>
      </header>
      <PaymentModal plan={plan} onClose={() => {}} onSuccess={() => void handleUnlocked()} />
    </div>
  )
}
