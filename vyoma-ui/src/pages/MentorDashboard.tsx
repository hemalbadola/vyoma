import { useEffect, useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import Sidebar from '../components/Sidebar';
import { type StudentSummary, type StudentAnalytics, type MentorDashboardStats } from '../services/api';
import './MentorDashboard.css';

export default function MentorDashboard() {
  const { user } = useAuth();
  const [students, setStudents] = useState<StudentSummary[]>([]);
  const [dashboardStats, setDashboardStats] = useState<MentorDashboardStats | null>(null);
  const [selectedStudent, setSelectedStudent] = useState<StudentAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [linkEmail, setLinkEmail] = useState('');
  const [linkingStudent, setLinkingStudent] = useState(false);

  useEffect(() => {
    if (!user) return;

    // Mock data for showcase
    setDashboardStats({
      total_students: 0,
      active_students_last_7_days: 0,
      inactive_students: 0,
      total_papers_saved: 0,
      papers_saved_this_week: 0,
      avg_papers_per_student: 0,
    });
    setStudents([]);
    setLoading(false);
  }, [user]);

  const handleLinkStudent = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!linkEmail.trim()) return;

    setLinkingStudent(true);
    
    // Mock linking for showcase
    setTimeout(() => {
      const newStudent: StudentSummary = {
        id: students.length + 1,
        email: linkEmail,
        display_name: linkEmail.split('@')[0],
        full_name: linkEmail.split('@')[0].charAt(0).toUpperCase() + linkEmail.split('@')[0].slice(1),
        papers_saved: 0,
        collections_created: 0,
        citations_made: 0,
        chat_sessions: 0,
        activities_last_week: 0,
        last_activity: new Date().toISOString(),
        mentorship_started: new Date().toISOString(),
      };

      setStudents([...students, newStudent]);
      
      // Update stats
      if (dashboardStats) {
        setDashboardStats({
          ...dashboardStats,
          total_students: dashboardStats.total_students + 1,
        });
      }

      alert(`✅ ${newStudent.full_name} (${linkEmail}) linked successfully!`);
      setLinkEmail('');
      setLinkingStudent(false);
    }, 500);
  };

  const handleUnlinkStudent = async (studentId: number, studentName: string) => {
    if (!confirm(`Remove ${studentName} from your students list?`)) return;

    // Mock unlink for showcase
    setStudents(students.filter(s => s.id !== studentId));
    
    // Update stats
    if (dashboardStats) {
      setDashboardStats({
        ...dashboardStats,
        total_students: dashboardStats.total_students - 1,
      });
    }

    alert(`${studentName} unlinked successfully`);
  };

  const viewStudentDetails = async (studentId: number) => {
    const student = students.find(s => s.id === studentId);
    if (!student) return;

    // Mock analytics for showcase
    const analytics: StudentAnalytics = {
      student_id: student.id,
      student_name: student.display_name || student.full_name || 'Student',
      total_papers: student.papers_saved,
      total_citations: student.citations_made,
      total_collections: student.collections_created,
      total_chat_sessions: student.chat_sessions,
      papers_last_7_days: 0,
      papers_last_30_days: student.papers_saved,
      avg_papers_per_week: 0,
      research_topics: [],
      last_activity: student.last_activity || new Date().toISOString(),
    };

    setSelectedStudent(analytics);
  };

  if (!user) return null;

  return (
    <div className="dashboard-wrapper">
      <div className="dashboard-bg">
        <div className="bg-gradient"></div>
        <div className="bg-grid"></div>
      </div>

      <Sidebar user={user} />

      <main className="main-content">
        <header className="main-header">
          <div>
            <h2 className="welcome-text">Mentor Dashboard</h2>
            <p className="subtitle-text">Track your students' research progress</p>
          </div>
        </header>

        {/* Dashboard Stats */}
        {dashboardStats && (
          <div className="stats-grid">
            <div className="stat-card">
              <div className="stat-icon">👥</div>
              <div className="stat-content">
                <p className="stat-label">Total Students</p>
                <p className="stat-value">{dashboardStats.total_students}</p>
              </div>
            </div>

            <div className="stat-card">
              <div className="stat-icon">🟢</div>
              <div className="stat-content">
                <p className="stat-label">Active (7 days)</p>
                <p className="stat-value">{dashboardStats.active_students_last_7_days}</p>
              </div>
            </div>

            <div className="stat-card">
              <div className="stat-icon">📚</div>
              <div className="stat-content">
                <p className="stat-label">Total Papers</p>
                <p className="stat-value">{dashboardStats.total_papers_saved}</p>
              </div>
            </div>

            <div className="stat-card">
              <div className="stat-icon">📈</div>
              <div className="stat-content">
                <p className="stat-label">This Week</p>
                <p className="stat-value">{dashboardStats.papers_saved_this_week}</p>
              </div>
            </div>
          </div>
        )}

        {/* Link New Student */}
        <div className="link-student-section">
          <h3>Link New Student</h3>
          <form onSubmit={handleLinkStudent} className="link-form">
            <input
              type="email"
              placeholder="Student's email address"
              value={linkEmail}
              onChange={(e) => setLinkEmail(e.target.value)}
              required
              disabled={linkingStudent}
            />
            <button type="submit" disabled={linkingStudent}>
              {linkingStudent ? 'Linking...' : '+ Link Student'}
            </button>
          </form>
        </div>

        {/* Students List */}
        <div className="students-section">
          <h3>My Students ({students.length})</h3>
          
          {loading ? (
            <div className="loading-state">
              <div className="loading-spinner"></div>
              <p>Loading students...</p>
            </div>
          ) : students.length === 0 ? (
            <div className="empty-state">
              <svg viewBox="0 0 24 24" fill="none" width="64" height="64">
                <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" stroke="currentColor" strokeWidth="2"/>
              </svg>
              <h3>No Students Yet</h3>
              <p>Link students using their email address to start tracking their research</p>
            </div>
          ) : (
            <div className="students-grid">
              {students.map(student => (
                <div key={student.id} className="student-card">
                  <div className="student-header">
                    <div className="student-avatar">
                      {(student.display_name || student.email).charAt(0).toUpperCase()}
                    </div>
                    <div className="student-info">
                      <h4>{student.display_name || student.full_name || 'Unnamed Student'}</h4>
                      <p className="student-email">{student.email}</p>
                    </div>
                  </div>

                  <div className="student-stats">
                    <div className="student-stat">
                      <span className="stat-icon">📄</span>
                      <span>{student.papers_saved} papers</span>
                    </div>
                    <div className="student-stat">
                      <span className="stat-icon">📂</span>
                      <span>{student.collections_created} collections</span>
                    </div>
                    <div className="student-stat">
                      <span className="stat-icon">🔗</span>
                      <span>{student.citations_made} citations</span>
                    </div>
                    <div className="student-stat">
                      <span className="stat-icon">💬</span>
                      <span>{student.chat_sessions} chats</span>
                    </div>
                  </div>

                  <div className="student-activity">
                    <p className="activity-label">Last 7 days activity</p>
                    <div className="activity-bar">
                      <div 
                        className="activity-fill" 
                        style={{ width: `${Math.min(100, student.activities_last_week * 10)}%` }}
                      ></div>
                    </div>
                    <p className="activity-count">{student.activities_last_week} actions</p>
                  </div>

                  {student.last_activity && (
                    <p className="last-activity">
                      Last active: {new Date(student.last_activity).toLocaleDateString()}
                    </p>
                  )}

                  <div className="student-actions">
                    <button 
                      onClick={() => viewStudentDetails(student.id)}
                      className="view-btn"
                    >
                      📊 View Details
                    </button>
                    <button 
                      onClick={() => handleUnlinkStudent(student.id, student.display_name || student.email)}
                      className="unlink-btn"
                    >
                      🗑️
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Student Details Modal */}
        {selectedStudent && (
          <div className="modal-overlay" onClick={() => setSelectedStudent(null)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()}>
              <button className="modal-close" onClick={() => setSelectedStudent(null)}>×</button>
              
              <h2>{selectedStudent.student_name}</h2>
              
              <div className="analytics-grid">
                <div className="analytics-card">
                  <h4>Research Output</h4>
                  <div className="analytics-stats">
                    <div className="analytics-stat">
                      <span className="stat-value">{selectedStudent.total_papers}</span>
                      <span className="stat-label">Total Papers</span>
                    </div>
                    <div className="analytics-stat">
                      <span className="stat-value">{selectedStudent.total_citations}</span>
                      <span className="stat-label">Citations</span>
                    </div>
                    <div className="analytics-stat">
                      <span className="stat-value">{selectedStudent.total_collections}</span>
                      <span className="stat-label">Collections</span>
                    </div>
                  </div>
                </div>

                <div className="analytics-card">
                  <h4>Recent Activity</h4>
                  <div className="analytics-stats">
                    <div className="analytics-stat">
                      <span className="stat-value">{selectedStudent.papers_last_7_days}</span>
                      <span className="stat-label">Last 7 Days</span>
                    </div>
                    <div className="analytics-stat">
                      <span className="stat-value">{selectedStudent.papers_last_30_days}</span>
                      <span className="stat-label">Last 30 Days</span>
                    </div>
                    <div className="analytics-stat">
                      <span className="stat-value">{selectedStudent.avg_papers_per_week}</span>
                      <span className="stat-label">Avg/Week</span>
                    </div>
                  </div>
                </div>

                {selectedStudent.research_topics.length > 0 && (
                  <div className="analytics-card full-width">
                    <h4>Research Topics</h4>
                    <div className="topics-list">
                      {selectedStudent.research_topics.map((topic, idx) => (
                        <span key={idx} className="topic-tag">{topic}</span>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {selectedStudent.last_activity && (
                <p className="last-activity-detail">
                  Last active: {new Date(selectedStudent.last_activity).toLocaleString()}
                </p>
              )}
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
