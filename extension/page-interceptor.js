/**
 * Page-level fetch interceptor.
 *
 * This script is injected into the recorder.google.com page context
 * so it can monkey-patch the real window.fetch. It captures every
 * request/response and forwards them to the content script via
 * window.postMessage.
 *
 * It also listens for GRC_PROXY_FETCH messages from the content script
 * and executes fetch requests in the page context (inheriting cookies).
 *
 * Message format posted to window:
 *   { type: 'GRC_INTERCEPTED', payload: InterceptedRequest }
 */

const MAX_BODY_SIZE = 500_000; // 500KB cap to avoid 64MiB Chrome message limit

/** @type {typeof fetch} */
const originalFetch = window.fetch;

window.fetch = async function patchedFetch(input, init) {
  const url =
    typeof input === 'string'
      ? input
      : input instanceof URL
        ? input.href
        : input.url;

  const method = init?.method ?? 'GET';

  /** @type {Response} */
  let response;
  try {
    response = await originalFetch.call(this, input, init);
  } catch (err) {
    throw err;
  }

  const clone = response.clone();

  clone
    .text()
    .then((bodyText) => {
      /** @type {unknown} */
      let body;
      // Skip very large responses (audio blobs, etc.)
      if (bodyText.length > MAX_BODY_SIZE) {
        body = `[Truncated: ${bodyText.length} bytes]`;
      } else {
        try {
          body = JSON.parse(bodyText);
        } catch {
          body = bodyText;
        }
      }

      window.postMessage(
        {
          type: 'GRC_INTERCEPTED',
          payload: {
            url,
            method: method.toUpperCase(),
            status: response.status,
            body,
            requestBody: tryParseBody(init?.body),
            timestamp: Date.now(),
          },
        },
        '*'
      );
    })
    .catch(() => {
      // Silently ignore unreadable responses
    });

  return response;
};

// ---------------------------------------------------------------------------
// Proxy fetch: execute fetch commands from the content script
// ---------------------------------------------------------------------------

window.addEventListener('message', async (event) => {
  if (event.source !== window) return;
  if (event.data?.type !== 'GRC_PROXY_FETCH') return;

  const { callbackId, url, method, body } = event.data;

  try {
    const resp = await originalFetch(url, {
      method: method || 'GET',
      headers: body ? { 'Content-Type': 'application/json' } : {},
      body: body ? JSON.stringify(body) : undefined,
    });

    let responseBody;
    try {
      responseBody = await resp.json();
    } catch {
      responseBody = await resp.text();
    }

    window.postMessage({
      type: 'GRC_FETCH_RESULT',
      callbackId,
      body: responseBody,
      status: resp.status,
    }, '*');
  } catch (err) {
    window.postMessage({
      type: 'GRC_FETCH_RESULT',
      callbackId,
      error: err.message,
    }, '*');
  }
});

/**
 * Attempts to parse the request body.
 * @param {BodyInit | null | undefined} body
 * @returns {unknown}
 */
function tryParseBody(body) {
  if (!body) return undefined;
  if (typeof body === 'string') {
    try {
      return JSON.parse(body);
    } catch {
      return body;
    }
  }
  return undefined;
}

console.log('[GRC] Fetch interceptor installed on recorder.google.com');
