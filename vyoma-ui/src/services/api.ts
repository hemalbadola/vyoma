// API Service for Vyoma Backend
const API_BASE_URL = import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000';

// Helper function to handle API responses
async function handleResponse<T>(response: Response): Promise<T> {
  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: 'An error occurred' }));
    throw new Error(error.detail || `HTTP ${response.status}`);
  }
  return response.json();
}

// Papers API
export interface Paper {
  id: number;
  user_id: number;
  title: string;
  authors: string;
  publication_year?: number;
  venue?: string;
  doi?: string;
  pdf_url?: string;
  notes?: string;
  tags?: string;
  created_at: string;
  updated_at: string;
}

export interface PaperStats {
  total_papers: number;
  papers_by_year: Record<string, number>;
  top_venues: Array<{ venue: string; count: number }>;
  recent_papers: number;
}

export const papersApi = {
  async getStats(userId: number = 1): Promise<PaperStats> {
    const response = await fetch(`${API_BASE_URL}/api/papers/stats?user_id=${userId}`);
    return handleResponse<PaperStats>(response);
  },

  async list(userId: number = 1, skip: number = 0, limit: number = 50): Promise<Paper[]> {
    const response = await fetch(`${API_BASE_URL}/api/papers/?user_id=${userId}&skip=${skip}&limit=${limit}`);
    return handleResponse<Paper[]>(response);
  },

  async create(paper: Omit<Paper, 'id' | 'created_at' | 'updated_at'>): Promise<Paper> {
    const response = await fetch(`${API_BASE_URL}/api/papers/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(paper),
    });
    return handleResponse<Paper>(response);
  },
};

// Collections API
export interface Collection {
  id: number;
  user_id: number;
  name: string;
  description?: string;
  color: string;
  icon: string;
  is_public: boolean;
  paper_count: number;
  created_at: string;
  updated_at: string;
}

export interface CollectionStats {
  total_collections: number;
  total_papers_in_collections: number;
  public_collections: number;
  private_collections: number;
  most_used_collection?: {
    id: number;
    name: string;
    paper_count: number;
  };
}

export const collectionsApi = {
  async list(userId: number = 1, skip: number = 0, limit: number = 50): Promise<Collection[]> {
    const response = await fetch(`${API_BASE_URL}/api/collections/?user_id=${userId}&skip=${skip}&limit=${limit}`);
    return handleResponse<Collection[]>(response);
  },

  async getStats(userId: number = 1): Promise<CollectionStats> {
    const response = await fetch(`${API_BASE_URL}/api/collections/stats/summary?user_id=${userId}`);
    return handleResponse<CollectionStats>(response);
  },

  async create(collection: Omit<Collection, 'id' | 'paper_count' | 'created_at' | 'updated_at'>): Promise<Collection> {
    const response = await fetch(`${API_BASE_URL}/api/collections/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(collection),
    });
    return handleResponse<Collection>(response);
  },
};

// Citations API
export interface CitationLink {
  id: number;
  user_id: number;
  source_paper_id: string;
  target_paper_id: string;
  weight: number;
  note?: string;
  created_at: string;
}

export interface CitationStats {
  total_citations: number;
  unique_papers: number;
  most_cited_paper?: {
    paper_id: string;
    citation_count: number;
  };
  average_citations_per_paper: number;
}

export const citationsApi = {
  async list(userId: number = 1, skip: number = 0, limit: number = 100): Promise<CitationLink[]> {
    const response = await fetch(`${API_BASE_URL}/api/citations/?user_id=${userId}&skip=${skip}&limit=${limit}`);
    return handleResponse<CitationLink[]>(response);
  },

  async getStats(userId: number = 1): Promise<CitationStats> {
    const response = await fetch(`${API_BASE_URL}/api/citations/stats?user_id=${userId}`);
    return handleResponse<CitationStats>(response);
  },

  async create(citation: Omit<CitationLink, 'id' | 'created_at'>): Promise<CitationLink> {
    const response = await fetch(`${API_BASE_URL}/api/citations/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(citation),
    });
    return handleResponse<CitationLink>(response);
  },
};

// Activity API
export interface Activity {
  id: number;
  user_id: number;
  activity_type: string;
  description: string;
  entity_type?: string;
  entity_id?: number;
  created_at: string;
}

export const activityApi = {
  async getRecent(userId: number = 1, limit: number = 20): Promise<Activity[]> {
    const response = await fetch(`${API_BASE_URL}/api/activity/recent?user_id=${userId}&limit=${limit}`);
    return handleResponse<Activity[]>(response);
  },

  async log(activity: Omit<Activity, 'id' | 'created_at'>): Promise<Activity> {
    const response = await fetch(`${API_BASE_URL}/api/activity/log`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(activity),
    });
    return handleResponse<Activity>(response);
  },
};

// Search API
export interface SearchFilters {
  year_from?: number;
  year_to?: number;
  min_citations?: number;
  max_citations?: number;
  authors?: string[];
  institutions?: string[];
  open_access?: boolean;
  has_fulltext?: boolean;
  sort_by?: 'relevance' | 'cited_by_count' | 'publication_date';
}

export interface PaperAuthor {
  id?: string;
  name: string;
  institution?: string;
}

export interface SearchResult {
  id: string;
  title: string;
  authors: PaperAuthor[];
  publication_date?: string;
  publication_year?: number;
  venue?: string;
  cited_by_count: number;
  doi?: string;
  pdf_url?: string;
  abstract?: string;
  open_access: boolean;
}

export interface SearchResponse {
  query: string;
  enhanced_query?: string;
  results: SearchResult[];
  total_results: number;
  page: number;
  per_page: number;
  total_pages: number;
  search_time_ms: number;
}

const bearerHeaders = (token?: string) =>
  token ? { Authorization: `Bearer ${token}` } : ({} as Record<string, string>)

export const searchApi = {
  async search(
    query: string,
    token: string | undefined,
    filters?: SearchFilters,
    page: number = 1,
    perPage: number = 10,
    useAiEnhancement: boolean = true
  ): Promise<SearchResponse> {
    const response = await fetch(`${API_BASE_URL}/api/search/search`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...bearerHeaders(token)
      },
      body: JSON.stringify({
        query,
        filters,
        page,
        per_page: perPage,
        use_ai_enhancement: useAiEnhancement,
      }),
    });
    return handleResponse<SearchResponse>(response);
  },

  async savePaper(
    paper: {
      paper_id: string;
      title: string;
      authors?: string;
      summary?: string;
      published_year?: number;
      venue?: string;
      doi?: string;
      pdf_url?: string;
      cited_by_count?: number;
      tags?: string;
    },
    token: string | undefined
  ): Promise<Paper> {
    const response = await fetch(`${API_BASE_URL}/api/search/save-paper`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...bearerHeaders(token)
      },
      body: JSON.stringify(paper),
    });
    return handleResponse<Paper>(response);
  },

  async checkSaved(paperId: string, token: string | undefined): Promise<{ saved: boolean; saved_paper_id: number | null }> {
    const response = await fetch(`${API_BASE_URL}/api/search/check-saved/${encodeURIComponent(paperId)}`, {
      headers: {
        ...bearerHeaders(token)
      }
    });
    return handleResponse(response);
  },

  async getSuggestions(query: string): Promise<{ original_query: string; suggestions: string[]; enhanced_query: string }> {
    const response = await fetch(`${API_BASE_URL}/api/search/suggest?query=${encodeURIComponent(query)}`);
    return handleResponse(response);
  },

  async getStats(token: string | undefined): Promise<{ total_papers: number; database: string; last_updated: string }> {
    const response = await fetch(`${API_BASE_URL}/api/search/stats`, {
      headers: {
        ...bearerHeaders(token)
      }
    });
    return handleResponse(response);
  },
};

// Chat API
export interface ChatSession {
  id: number;
  user_id: number;
  title: string;
  model: string;
  message_count: number;
  last_message_at?: string;
  created_at: string;
  updated_at: string;
}

export interface ChatMessage {
  id: number;
  session_id: number;
  role: 'user' | 'assistant';
  content: string;
  paper_references?: string;
  token_count?: number;
  created_at: string;
}

export interface ChatStats {
  total_sessions: number;
  total_messages: number;
  last_chat_at?: string;
}

export const chatApi = {
  async listSessions(userId: number = 1, limit: number = 50): Promise<ChatSession[]> {
    const response = await fetch(`${API_BASE_URL}/api/chat/sessions?user_id=${userId}&limit=${limit}`);
    return handleResponse<ChatSession[]>(response);
  },

  async createSession(title: string, model: string = 'gemini', systemPrompt?: string): Promise<ChatSession> {
    const response = await fetch(`${API_BASE_URL}/api/chat/sessions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, model, system_prompt: systemPrompt }),
    });
    return handleResponse<ChatSession>(response);
  },

  async sendMessage(
    sessionId: number,
    content: string,
    paperReferences?: string[],
    useContext: boolean = true,
    model: string = 'gemini'
  ): Promise<ChatMessage> {
    const response = await fetch(`${API_BASE_URL}/api/chat/sessions/${sessionId}/messages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content, paper_references: paperReferences, use_context: useContext, model }),
    });
    return handleResponse<ChatMessage>(response);
  },

  async getStats(userId: number = 1): Promise<ChatStats> {
    const response = await fetch(`${API_BASE_URL}/api/chat/stats?user_id=${userId}`);
    return handleResponse<ChatStats>(response);
  },
};

// Health Check
export const healthApi = {
  async check(): Promise<{ status: string; message: string }> {
    const response = await fetch(`${API_BASE_URL}/health`);
    return handleResponse(response);
  },
};

// Mentor API
export interface StudentSummary {
  id: number;
  email: string;
  full_name?: string;
  display_name?: string;
  papers_saved: number;
  collections_created: number;
  citations_made: number;
  chat_sessions: number;
  last_activity?: string;
  mentorship_started: string;
  activities_last_week: number;
}

export interface StudentAnalytics {
  student_id: number;
  student_name: string;
  total_papers: number;
  total_collections: number;
  total_citations: number;
  total_chat_sessions: number;
  papers_last_7_days: number;
  papers_last_30_days: number;
  avg_papers_per_week: number;
  most_active_day?: string;
  research_topics: string[];
  last_activity?: string;
}

export interface MentorDashboardStats {
  total_students: number;
  active_students_last_7_days: number;
  inactive_students: number;
  total_papers_saved: number;
  papers_saved_this_week: number;
  avg_papers_per_student: number;
}

export const mentorApi = {
  async linkStudent(studentEmail: string, token: string): Promise<{ message: string; link_id: number; student_name: string }> {
    const response = await fetch(`${API_BASE_URL}/api/mentor/link-student`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ student_email: studentEmail }),
    });
    return handleResponse(response);
  },

  async unlinkStudent(studentId: number, token: string): Promise<{ message: string }> {
    const response = await fetch(`${API_BASE_URL}/api/mentor/unlink-student/${studentId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`
      },
    });
    return handleResponse(response);
  },

  async getMyStudents(token: string): Promise<StudentSummary[]> {
    const response = await fetch(`${API_BASE_URL}/api/mentor/my-students`, {
      headers: {
        'Authorization': `Bearer ${token}`
      },
    });
    return handleResponse(response);
  },

  async getStudentAnalytics(studentId: number, token: string): Promise<StudentAnalytics> {
    const response = await fetch(`${API_BASE_URL}/api/mentor/student/${studentId}/analytics`, {
      headers: {
        'Authorization': `Bearer ${token}`
      },
    });
    return handleResponse(response);
  },

  async getDashboard(token: string): Promise<MentorDashboardStats> {
    const response = await fetch(`${API_BASE_URL}/api/mentor/dashboard`, {
      headers: {
        'Authorization': `Bearer ${token}`
      },
    });
    return handleResponse(response);
  },
};

export default {
  papers: papersApi,
  collections: collectionsApi,
  citations: citationsApi,
  activity: activityApi,
  search: searchApi,
  chat: chatApi,
  health: healthApi,
  mentor: mentorApi,
};
