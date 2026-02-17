import { ExtensionApiClient } from '../services/extension-api-client.js';

/**
 * Wires up the discovery panel UI for inspecting captured API endpoints.
 * Only active when running in the Chrome extension context.
 */
export function initDiscoveryPanel(autoOpen = false): void {
  const discoverBtn = document.getElementById('discover-btn');
  const panel = document.getElementById('discovery-panel');
  const output = document.getElementById('discovery-output');
  const refreshBtn = document.getElementById('discovery-refresh');
  const closeBtn = document.getElementById('discovery-close');

  if (!discoverBtn || !panel || !output || !refreshBtn || !closeBtn) {
    return; // Discovery UI elements not present (standalone mode)
  }

  const client = new ExtensionApiClient();
  const outputEl = output;

  /** Fetches and displays captured endpoints. */
  async function refresh(): Promise<void> {
    outputEl.textContent = 'Loading captured requests…';
    try {
      const endpoints = await client.discoverEndpoints();
      const keys = Object.keys(endpoints);

      if (keys.length === 0) {
        outputEl.textContent =
          'No requests captured yet.\n\n' +
          'Make sure you have recorder.google.com open in a tab\n' +
          'and navigate around to trigger API calls.';
        return;
      }

      const summary = keys.map((key) => {
        const entries = endpoints[key] as Array<{ status: number; body: unknown }>;
        const sample = entries[entries.length - 1];
        return [
          `━━ ${key} (${entries.length} call${entries.length > 1 ? 's' : ''}) ━━`,
          `Status: ${sample.status}`,
          `Response: ${JSON.stringify(sample.body, null, 2).slice(0, 2000)}`,
          '',
        ].join('\n');
      });

      outputEl.textContent = summary.join('\n');
    } catch (err) {
      outputEl.textContent = `Error: ${err instanceof Error ? err.message : String(err)}`;
    }
  }

  discoverBtn.addEventListener('click', () => {
    panel.hidden = !panel.hidden;
    if (!panel.hidden) {
      refresh().catch(console.error);
    }
  });

  refreshBtn.addEventListener('click', () => {
    refresh().catch(console.error);
  });

  closeBtn.addEventListener('click', () => {
    panel.hidden = true;
  });

  // Auto-open discovery panel when in extension mode
  if (autoOpen) {
    panel.hidden = false;
    refresh().catch(console.error);
  }
}
