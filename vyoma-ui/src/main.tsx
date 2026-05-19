import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import './index.css'
import App from './App.tsx'
import Login from './pages/Login.tsx'
import ProfileSetup from './pages/ProfileSetup.tsx'
import Dashboard from './pages/Dashboard.tsx'
import Chat from './pages/Chat.tsx'
import FeatureStack from './pages/FeatureStack.tsx'
import Subscribe from './pages/Subscribe.tsx'
import ProtectedRoute from './components/ProtectedRoute.tsx'
import { AuthProvider } from './contexts/AuthContext.tsx'
import { UserProfileProvider } from './contexts/UserProfileContext.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <UserProfileProvider>
          <Routes>
            <Route path="/" element={<App />} />
            <Route path="/login" element={<Login />} />
            <Route
              path="/profile-setup"
              element={
                <ProtectedRoute requireProfile={false}>
                  <ProfileSetup />
                </ProtectedRoute>
              }
            />
            <Route
              path="/subscribe"
              element={
                <ProtectedRoute requireSubscription={false}>
                  <Subscribe />
                </ProtectedRoute>
              }
            />
            <Route
              path="/dashboard"
              element={
                <ProtectedRoute requireSubscription>
                  <Dashboard />
                </ProtectedRoute>
              }
            />
            <Route
              path="/feature-stack"
              element={
                <ProtectedRoute requireSubscription>
                  <FeatureStack />
                </ProtectedRoute>
              }
            />
            <Route
              path="/chat"
              element={
                <ProtectedRoute requireSubscription>
                  <Chat />
                </ProtectedRoute>
              }
            />
            <Route path="/app" element={<Navigate to="/dashboard" replace />} />
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </UserProfileProvider>
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>
)
