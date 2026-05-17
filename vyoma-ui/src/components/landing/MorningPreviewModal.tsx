const TERMINAL_PREVIEW = `07:58 AM  ↳ Syncing calendar...  3 meetings today
        ↳ Reading task board... 2 items due today
        ↳ Focus windows available: 11:00–12:30, 4:00–5:00

08:00 AM  ↳ Deadline: Project draft — due 3:00 PM
        ↳ Recommended window: 11:00 AM session
        ↳ Setting ambient reminder for 10:50 AM

08:01 AM  ↳ Your day is ready.

This happens every morning.
Without you asking.`

type MorningPreviewModalProps = {
  open: boolean
  onClose: () => void
}

export default function MorningPreviewModal({ open, onClose }: MorningPreviewModalProps) {
  if (!open) return null

  return (
    <div className="vyoma-modal-overlay" role="dialog" aria-modal="true" aria-labelledby="morning-modal-title">
      <button type="button" className="vyoma-modal-backdrop" onClick={onClose} aria-label="Close preview" />
      <div className="vyoma-modal vyoma-morning-modal">
        <p className="act-label">Act 4 — Terminal</p>
        <h2 id="morning-modal-title" className="vyoma-morning-modal__title">
          What Vyoma does at 8am for you
        </h2>
        <pre className="terminal-text vyoma-morning-modal__terminal">{TERMINAL_PREVIEW}</pre>
        <button type="button" className="vyoma-btn-gold" onClick={onClose}>
          Close preview
        </button>
      </div>
    </div>
  )
}
