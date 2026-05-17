import type { ReactNode } from 'react'
import Sidebar from '../components/Sidebar'
import '../styles/vyoma-app.css'

type VyomaAppLayoutProps = {
  children: ReactNode
}

export default function VyomaAppLayout({ children }: VyomaAppLayoutProps) {
  return (
    <div className="vyoma-app">
      <div className="vyoma-app-bg" aria-hidden="true">
        <div className="vyoma-app-bg__glow" />
        <div className="vyoma-app-bg__grid" />
      </div>
      <Sidebar />
      <main className="vyoma-app-main">{children}</main>
    </div>
  )
}
