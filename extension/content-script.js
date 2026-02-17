/**
 * Content script for recorder.google.com.
 *
 * Responsibilities:
 * 1. Inject the page-interceptor.js into the page context
 * 2. Listen for intercepted fetch messages from the page
 * 3. Forward them to the background service worker via chrome.runtime
 * 4. Relay commands from the side panel back to the page via postMessage
 */

// ---------------------------------------------------------------------------
// 1. Inject page-level interceptor
// ---------------------------------------------------------------------------

const script = document.createElement('script');
script.src = chrome.runtime.getURL('page-interceptor.js');
script.onload = () => script.remove();
(document.head || document.documentElement).appendChild(script);

// ---------------------------------------------------------------------------
// 2. Listen for intercepted fetch messages from the page
// ---------------------------------------------------------------------------

/** @type {Map<string, unknown[]>} URL → array of captured responses */
const capturedResponses = new Map();

window.addEventListener('message', (event) => {
  if (event.source !== window) return;

  if (event.data?.type === 'GRC_INTERCEPTED') {
    const payload = event.data.payload;

    // Store locally for the content script bridge
    const key = `${payload.method} ${payload.url}`;
    if (!capturedResponses.has(key)) {
      capturedResponses.set(key, []);
    }
    capturedResponses.get(key).push(payload);

    // Forward to background service worker (with size guard)
    try {
      chrome.runtime.sendMessage({
        type: 'GRC_INTERCEPTED',
        payload,
      });
    } catch (err) {
      console.warn('[GRC] Could not forward intercepted message:', err.message);
    }
  }
});

// ---------------------------------------------------------------------------
// 3. Listen for commands from the side panel (via background)
// ---------------------------------------------------------------------------

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === 'GRC_GET_CAPTURED') {
    // Return all captured data so the panel can inspect endpoints
    const data = Object.fromEntries(capturedResponses);
    sendResponse({ captured: data });
    return true;
  }

  if (message.type === 'GRC_FETCH') {
    // Proxy a fetch request through the page's authenticated session
    // Uses postMessage → page-interceptor.js (no inline scripts, no CSP issue)
    proxyFetch(message.payload)
      .then((result) => sendResponse({ ok: true, data: result }))
      .catch((err) => sendResponse({ ok: false, error: err.message }));
    return true; // async sendResponse
  }

  return false;
});

/**
 * Proxies a fetch request through the page context via postMessage
 * to the page-interceptor.js (which runs in the page's JS context
 * and inherits the user's authenticated cookies).
 *
 * @param {{ url: string, method?: string, body?: unknown }} opts
 * @returns {Promise<unknown>}
 */
function proxyFetch(opts) {
  return new Promise((resolve, reject) => {
    const callbackId = `grc_cb_${Date.now()}_${Math.random().toString(36).slice(2)}`;

    /** @param {MessageEvent} event */
    const handler = (event) => {
      if (event.source !== window) return;
      if (event.data?.type !== 'GRC_FETCH_RESULT') return;
      if (event.data.callbackId !== callbackId) return;

      window.removeEventListener('message', handler);

      if (event.data.error) {
        reject(new Error(event.data.error));
      } else {
        resolve(event.data.body);
      }
    };
    window.addEventListener('message', handler);

    // Send fetch command to page-interceptor.js via postMessage
    window.postMessage({
      type: 'GRC_PROXY_FETCH',
      callbackId,
      url: opts.url,
      method: opts.method ?? 'GET',
      body: opts.body,
    }, '*');

    // Timeout after 15 seconds
    setTimeout(() => {
      window.removeEventListener('message', handler);
      reject(new Error('Proxy fetch timed out'));
    }, 15_000);
  });
}

console.log('[GRC] Content script loaded on recorder.google.com');
