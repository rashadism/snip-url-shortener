// State
let currentUser = localStorage.getItem('snip_username') || '';
let currentView = 'welcome';

// Init
document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('username-form').addEventListener('submit', handleLogin);
  document.getElementById('shorten-form').addEventListener('submit', handleShorten);
  document.getElementById('logout-btn').addEventListener('click', handleLogout);

  if (currentUser) {
    navigateTo('dashboard');
  }
});

// Navigation
function navigateTo(view, data) {
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
  document.getElementById(view).classList.add('active');
  currentView = view;

  if (view === 'dashboard') {
    document.getElementById('display-username').textContent = currentUser;
    loadURLs();
  } else if (view === 'analytics' && data) {
    document.getElementById('analytics-username').textContent = currentUser;
    loadAnalytics(data.code);
  }
}

// Auth
function handleLogin(e) {
  e.preventDefault();
  const input = document.getElementById('username-input');
  const username = input.value.trim();
  if (!username) return;

  currentUser = username;
  localStorage.setItem('snip_username', username);
  input.value = '';
  navigateTo('dashboard');
}

function handleLogout() {
  currentUser = '';
  localStorage.removeItem('snip_username');
  navigateTo('welcome');
}

// Shorten
async function handleShorten(e) {
  e.preventDefault();
  const urlInput = document.getElementById('url-input');
  const slugInput = document.getElementById('slug-input');
  const resultDiv = document.getElementById('shorten-result');
  const errorDiv = document.getElementById('shorten-error');

  resultDiv.classList.add('hidden');
  errorDiv.classList.add('hidden');

  const body = {
    url: urlInput.value.trim(),
    username: currentUser,
  };
  const slug = slugInput.value.trim();
  if (slug) body.custom_slug = slug;

  try {
    const resp = await fetch('/api/shorten', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const data = await resp.json();

    if (!resp.ok) {
      errorDiv.textContent = data.error || 'Something went wrong';
      errorDiv.classList.remove('hidden');
      return;
    }

    const shortURL = window.location.origin + '/r/' + data.short_code;
    resultDiv.innerHTML = `
      <span class="short-url">${shortURL}</span>
      <div>
        <span class="copy-feedback" id="copy-feedback">copied!</span>
        <button class="btn btn-sm btn-accent" onclick="copyURL('${shortURL}')">copy</button>
      </div>
    `;
    resultDiv.classList.remove('hidden');
    urlInput.value = '';
    slugInput.value = '';
    loadURLs();
  } catch (err) {
    errorDiv.textContent = 'Network error — is the server running?';
    errorDiv.classList.remove('hidden');
  }
}

function copyURL(url) {
  navigator.clipboard.writeText(url).then(() => {
    const fb = document.getElementById('copy-feedback');
    fb.classList.add('show');
    setTimeout(() => fb.classList.remove('show'), 1500);
  });
}

// Load URLs
async function loadURLs() {
  const list = document.getElementById('urls-list');

  try {
    const resp = await fetch(`/api/urls?username=${encodeURIComponent(currentUser)}`);
    const urls = await resp.json();

    if (!urls || urls.length === 0) {
      list.innerHTML = '<p class="empty-state">no URLs yet — create your first one above</p>';
      return;
    }

    list.innerHTML = urls.map((u, i) => {
      const favicon = u.favicon_url
        ? `<img class="favicon" src="${escapeHtml(u.favicon_url)}" alt="" onerror="this.style.display='none'">`
        : '<div class="favicon" style="background:var(--border);"></div>';

      const title = u.title
        ? `<div class="url-card-title">${escapeHtml(u.title)}</div>`
        : '';

      return `
        <div class="url-card" style="animation-delay: ${i * 0.05}s">
          ${favicon}
          <div class="url-card-info">
            <div class="url-card-code">/r/${escapeHtml(u.short_code)}</div>
            ${title}
            <div class="url-card-original">${escapeHtml(u.original_url)}</div>
          </div>
          <div class="url-card-actions">
            <span class="click-count" onclick="navigateTo('analytics', {code: '${u.short_code}'})">${u.click_count} clicks</span>
            <button class="btn btn-sm btn-accent" onclick="copyURL('${window.location.origin}/r/${u.short_code}')">copy</button>
            <button class="btn btn-sm btn-danger" onclick="deleteURL('${u.short_code}')">delete</button>
          </div>
        </div>
      `;
    }).join('');
  } catch (err) {
    list.innerHTML = '<p class="empty-state">failed to load URLs</p>';
  }
}

// Delete URL
async function deleteURL(code) {
  if (!confirm(`Delete /r/${code}?`)) return;
  try {
    await fetch(`/api/urls/${code}`, { method: 'DELETE' });
    loadURLs();
  } catch (err) {
    alert('Failed to delete URL');
  }
}

// Analytics
async function loadAnalytics(code) {
  const content = document.getElementById('analytics-content');
  content.innerHTML = '<div class="loading">loading analytics...</div>';

  try {
    const resp = await fetch(`/api/analytics/${code}`);
    if (!resp.ok) {
      content.innerHTML = '<div class="loading">URL not found</div>';
      return;
    }
    const data = await resp.json();

    const recentHTML = data.recent_clicks && data.recent_clicks.length > 0
      ? data.recent_clicks.map((c, i) => {
          const t = new Date(c.clicked_at);
          return `
            <div class="click-item" style="animation-delay: ${i * 0.04}s">
              <span class="click-time">${t.toLocaleString()}</span>
              <span class="click-ago">${timeAgo(t)}</span>
            </div>
          `;
        }).join('')
      : '<p class="empty-state">no clicks yet</p>';

    const createdAt = new Date(data.created_at);

    content.innerHTML = `
      <div class="analytics-header">
        <h2>/r/${escapeHtml(data.short_code)}</h2>
        ${data.title ? `<div style="font-size:15px;margin:4px 0">${escapeHtml(data.title)}</div>` : ''}
        <div class="original-url">${escapeHtml(data.original_url)}</div>
      </div>
      <div class="analytics-stats">
        <div class="stat-card">
          <div class="stat-value">${data.click_count}</div>
          <div class="stat-label">total clicks</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${createdAt.toLocaleDateString()}</div>
          <div class="stat-label">created</div>
        </div>
      </div>
      <div class="recent-clicks">
        <h3>recent clicks</h3>
        <div class="click-timeline">${recentHTML}</div>
      </div>
    `;
  } catch (err) {
    content.innerHTML = '<div class="loading">failed to load analytics</div>';
  }
}

// Helpers
function escapeHtml(str) {
  if (!str) return '';
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function timeAgo(date) {
  const seconds = Math.floor((new Date() - date) / 1000);
  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}
