import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import './index.css'
import App from './App.tsx'
import Login from './pages/Login.tsx'
import ProfileSetup from './pages/ProfileSetup.tsx'
import Dashboard from './pages/Dashboard.tsx'
import Chat from './pages/Chat.tsx'
import FeatureStack from './pages/FeatureStack.tsx'
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
              path="/dashboard"
              element={
                <ProtectedRoute>
                  <Dashboard />
                </ProtectedRoute>
              }
            />
            <Route
              path="/feature-stack"
              element={
                <ProtectedRoute>
                  <FeatureStack />
                </ProtectedRoute>
              }
            />
            <Route
              path="/chat"
              element={
                <ProtectedRoute>
                  <Chat />
                </ProtectedRoute>
              }
            />
            {/* Legacy research routes → War Room until rebuilt */}
            <Route path="/search" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
            <Route path="/scholar-search" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
            <Route path="/library" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
            <Route path="/network" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
            <Route path="/mentor" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
          </Routes>
        </UserProfileProvider>
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>
)
