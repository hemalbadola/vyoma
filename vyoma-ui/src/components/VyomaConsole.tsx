import { useCallback, useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { useAuth } from '../contexts/AuthContext'
import api from '../services/api'
import './VyomaConsole.css'

type BackendStatusTone = 'neutral' | 'success' | 'error'

type BackendStatus = {
  message: string
  tone: BackendStatusTone
  loading: boolean
}

type VyomaAuthor = {
  id?: string
  name: string
  institution?: string
}

type VyomaResult = {
  id: string
  title: string
  authors: VyomaAuthor[]
  publication_date?: string
  publication_year?: number
  venue?: string
  cited_by_count: number
  doi?: string
  pdf_url?: string
  abstract?: string
  open_access: boolean
  relevance_score?: number
}

const PRESETS = [
  {
    value: 'Find the most cited reinforcement learning papers since 2021',
    label: 'Reinforcement Learning Since 2021'
  },
  {
    value: 'Show me open access quantum computing papers from 2023 onwards',
    label: 'Quantum Computing OA 2023+'
  },
  {
    value: 'List top collaborations between University of Florida and MIT in biomedicine',
    label: 'UF x MIT Biomed Collaborations'
  }
]

const formatNumber = (value?: number) => {
  if (typeof value !== 'number') return undefined
  return new Intl.NumberFormat('en-US').format(value)
}

const resolveBackendBaseUrl = () => {
  const envUrl = import.meta.env.VITE_BACKEND_URL?.trim()
  if (envUrl) return envUrl.replace(/\/$/, '')

  const raw = window.VYOMA_BACKEND?.trim()
  if (raw) return raw.replace(/\/$/, '')

  return 'http://127.0.0.1:8000'
}

export default function VyomaConsole() {
  const { getApiToken } = useAuth()
  const backendBaseUrl = useMemo(resolveBackendBaseUrl, [])

  const [query, setQuery] = useState('')
  const [perPage, setPerPage] = useState(5)
  const [page, setPage] = useState(1)
  const [presetValue, setPresetValue] = useState('')
  const [status, setStatus] = useState<BackendStatus>({ message: '', tone: 'neutral', loading: false })
  const [results, setResults] = useState<VyomaResult[]>([])
  const [meta, setMeta] = useState<{ count?: number } | undefined>()
  const [pagination, setPagination] = useState<{ page?: number } | undefined>()
  const [hasFetched, setHasFetched] = useState(false)
  const [savedPaperIds, setSavedPaperIds] = useState<Set<string>>(new Set())
  const [savingPaperId, setSavingPaperId] = useState<string | null>(null)

  const testBackendConnection = useCallback(async () => {
    setStatus({ message: 'Testing backend connection…', tone: 'neutral', loading: true })
    try {
      const response = await fetch(`${backendBaseUrl}/health`, { method: 'GET' })
      if (response.ok) {
        setStatus({ message: `✓ Backend connected at ${backendBaseUrl}`, tone: 'success', loading: false })
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (error) {
      const detail = error instanceof Error ? error.message : 'Unreachable'
      setStatus({
        message: `✗ Cannot reach backend at ${backendBaseUrl} (${detail})`,
        tone: 'error',
        loading: false
      })
    }
  }, [backendBaseUrl])

  useEffect(() => {
    testBackendConnection()
  }, [testBackendConnection])

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    if (!query.trim()) {
      setStatus({ message: 'Enter a research question to begin.', tone: 'error', loading: false })
      return
    }

    setStatus({ message: 'Translating prompt via Gemini & querying OpenAlex…', tone: 'neutral', loading: true })

    try {
      const token = await getApiToken()
      const data = await api.search.search(query.trim(), token, undefined, page, perPage, true)
      
      const payload = data.results ?? []
      setResults(payload)
      setMeta({ count: data.total_results })
      setPagination({ page: data.page })
      setHasFetched(true)

      // Check which papers are already saved
      const savedChecks = await Promise.all(
        payload.map(async (paper) => {
          try {
            const result = await api.search.checkSaved(paper.id, token)
            return result.saved ? paper.id : null
          } catch {
            return null
          }
        })
      )
      setSavedPaperIds(new Set(savedChecks.filter((id): id is string => id !== null)))

      const count = payload.length
      setStatus({
        message: `Fetched ${count} result${count === 1 ? '' : 's'} from Vyoma backend. Total: ${data.total_results}`,
        tone: 'success',
        loading: false
      })
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unexpected error occurred.'
      setResults([])
      setMeta(undefined)
      setPagination(undefined)
      setHasFetched(true)
      setStatus({ message: `Error: ${message}`, tone: 'error', loading: false })
    }
  }

  const handleSavePaper = async (paper: VyomaResult) => {
    try {
      setSavingPaperId(paper.id)
      
      const token = await getApiToken()

      // Prepare paper data
      const authorsText = paper.authors.map(a => a.name).join(', ')
      
      await api.search.savePaper({
        paper_id: paper.id,
        title: paper.title,
        authors: authorsText || undefined,
        summary: paper.abstract || undefined,
        published_year: paper.publication_year || undefined,
        venue: paper.venue || undefined,
        doi: paper.doi || undefined,
        pdf_url: paper.pdf_url || undefined,
        cited_by_count: paper.cited_by_count || undefined,
      }, token)

      // Update saved state
      setSavedPaperIds(prev => new Set([...prev, paper.id]))
      setStatus({
        message: `✓ Saved "${paper.title.substring(0, 50)}..." to your library`,
        tone: 'success',
        loading: false
      })
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to save paper'
      setStatus({
        message: `Error saving paper: ${message}`,
        tone: 'error',
        loading: false
      })
    } finally {
      setSavingPaperId(null)
    }
  }

  const handleClear = () => {
    setQuery('')
    setPerPage(5)
    setPage(1)
    setPresetValue('')
    setResults([])
    setMeta(undefined)
    setPagination(undefined)
    setHasFetched(false)
    setStatus({ message: '', tone: 'neutral', loading: false })
  }

  const displayStatusMessage = status.message || `Vyoma backend ready at ${backendBaseUrl}`

  const statusClassName = `vyoma-console__status vyoma-console__status--${status.tone}`

  const shouldShowPlaceholder = !hasFetched && results.length === 0
  const showEmptyState = hasFetched && results.length === 0 && status.tone !== 'error'

  return (
    <section className="vyoma-console" aria-labelledby="vyoma-console-title">
      <header className="vyoma-console__header">
        <div>
          <p className="vyoma-console__tag">Live Prototype</p>
          <h2 id="vyoma-console-title" className="vyoma-console__title">Ask Vyoma Anything</h2>
          <p className="vyoma-console__subtitle">
            Run natural-language queries against the running backend. We translate your intent, call OpenAlex, and surface
            open-access links without leaving the dashboard.
          </p>
        </div>
        <div className={statusClassName}>
          {status.loading && <span className="vyoma-console__spinner" />}
          <span className="vyoma-console__status-text">{displayStatusMessage}</span>
        </div>
      </header>

      <form className="vyoma-console__form" onSubmit={handleSubmit}>
        <label className="vyoma-console__field">
          <span className="vyoma-console__label">Research Question</span>
          <textarea
            className="vyoma-console__textarea"
            placeholder="e.g. Find the most cited reinforcement learning papers since 2021 with open source implementations"
            required
            spellCheck={false}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>

        <div className="vyoma-console__controls">
          <label className="vyoma-console__field">
            <span className="vyoma-console__label">Per Page</span>
            <select className="vyoma-console__input" value={perPage} onChange={(event) => setPerPage(Number(event.target.value))}>
              <option value={5}>5 results</option>
              <option value={10}>10 results</option>
              <option value={25}>25 results</option>
            </select>
          </label>
          <label className="vyoma-console__field">
            <span className="vyoma-console__label">Page</span>
            <input
              className="vyoma-console__input"
              type="number"
              min={1}
              value={page}
              onChange={(event) => setPage(Number(event.target.value) || 1)}
            />
          </label>
          <label className="vyoma-console__field">
            <span className="vyoma-console__label">Preset Queries</span>
            <select
              className="vyoma-console__input"
              value={presetValue}
              onChange={(event) => {
                const value = event.target.value
                setPresetValue(value)
                if (value) setQuery(value)
              }}
            >
              <option value="">Choose a preset</option>
              {PRESETS.map((preset) => (
                <option key={preset.label} value={preset.value}>
                  {preset.label}
                </option>
              ))}
            </select>
          </label>
        </div>

        <div className="vyoma-console__actions">
          <button type="button" className="vyoma-console__button vyoma-console__button--secondary" onClick={handleClear}>
            Clear
          </button>
          <button type="submit" className="vyoma-console__button vyoma-console__button--primary">
            Run Query
          </button>
        </div>
      </form>

      <div className="vyoma-console__results" aria-live="polite">
        {shouldShowPlaceholder && (
          <p className="vyoma-console__placeholder">Run a query to see Vyoma synthesize live intelligence.</p>
        )}

        {showEmptyState && status.tone !== 'error' && (
          <p className="vyoma-console__placeholder">No works found for this query. Adjust your filters or try another preset.</p>
        )}

        {results.length > 0 && (
          <div className="vyoma-console__result-summary">
            <span>Showing {results.length} results</span>
            <span>Page {pagination?.page ?? 1}</span>
            <span>
              OpenAlex total{' '}
              <span className="vyoma-console__result-summary-count">{formatNumber(meta?.count) ?? '—'}</span>
            </span>
          </div>
        )}

        {results.map((item) => {
          const citationCount = formatNumber(item.cited_by_count)
          const proxyUrl = item.pdf_url
            ? `${backendBaseUrl}/pdf?url=${encodeURIComponent(item.pdf_url)}`
            : undefined
          
          const authorsText = item.authors.slice(0, 3).map(a => a.name).join(', ') + 
            (item.authors.length > 3 ? ` +${item.authors.length - 3} more` : '')

          return (
            <article key={item.id} className="vyoma-console__result-card">
              <h3 className="vyoma-console__result-title">{item.title}</h3>

              {authorsText && (
                <p className="vyoma-console__result-source">{authorsText}</p>
              )}

              <div className="vyoma-console__result-meta">
                {item.publication_year && <span>{item.publication_year}</span>}
                {item.venue && <span>{item.venue}</span>}
                {citationCount && <span>{citationCount} citations</span>}
                {item.open_access && <span>Open Access</span>}
                {item.doi && (
                  <span>
                    DOI: <a className="vyoma-console__link" target="_blank" rel="noopener" href={item.doi}>{item.doi.replace('https://doi.org/', '')}</a>
                  </span>
                )}
              </div>

              {item.abstract && (
                <p className="vyoma-console__result-abstract">
                  {item.abstract.substring(0, 300)}{item.abstract.length > 300 ? '...' : ''}
                </p>
              )}

              <div className="vyoma-console__result-actions">
                {savedPaperIds.has(item.id) ? (
                  <button
                    className="vyoma-console__chip vyoma-console__chip--saved"
                    disabled
                  >
                    ✓ Saved to Library
                  </button>
                ) : (
                  <button
                    className="vyoma-console__chip vyoma-console__chip--save"
                    onClick={() => handleSavePaper(item)}
                    disabled={savingPaperId === item.id}
                  >
                    {savingPaperId === item.id ? 'Saving...' : '+ Save to Library'}
                  </button>
                )}
                {proxyUrl && (
                  <a href={proxyUrl} target="_blank" rel="noopener" className="vyoma-console__chip">
                    Open Access PDF
                  </a>
                )}
                {item.id && (
                  <a
                    href={`https://openalex.org/works/${item.id}`}
                    target="_blank"
                    rel="noopener"
                    className="vyoma-console__chip"
                  >
                    View on OpenAlex
                  </a>
                )}
              </div>
            </article>
          )
        })}
      </div>
    </section>
  )
}
