import type { ApiClient } from './types/api-client.js';
import { MockApiClient } from './services/mock-api-client.js';
import { ExtensionApiClient } from './services/extension-api-client.js';
import { RecordingService } from './services/recording-service.js';
import { RecordingsUI } from './ui/recordings-ui.js';
import { initDiscoveryPanel } from './ui/discovery-panel.js';

/**
 * Detects whether the app is running inside a Chrome extension context.
 */
function isExtensionContext(): boolean {
  return typeof chrome !== 'undefined' && !!chrome.runtime?.id;
}

/**
 * Bootstraps the application.
 * Uses the real ExtensionApiClient when running as a Chrome extension,
 * or MockApiClient for standalone development.
 */
function main(): void {
  const inExtension = isExtensionContext();

  // Use MockApiClient in both modes for now — the real API endpoints
  // are not yet discovered. The discovery panel lets you find them.
  const apiClient: ApiClient = new MockApiClient();
  const service = new RecordingService(apiClient, 'Mark');
  const ui = new RecordingsUI(service);
  ui.init().catch(console.error);

  if (inExtension) {
    initDiscoveryPanel(true);
    console.log('[GRC] Running in extension mode — discovery panel auto-opened');
  } else {
    console.log('[GRC] Running in standalone mode — using mock data');
  }
}

document.addEventListener('DOMContentLoaded', main);
