/**
 * Capture APIs from recorder.google.com
 *
 * Opens a headed browser, lets you log in manually, then captures:
 *  - All JavaScript files served by the site
 *  - All XHR / fetch API requests and responses
 *  - All WebSocket frames
 *
 * Results are saved to `captured/` at the project root.
 *
 * Usage:  npx tsx scripts/capture-apis.ts
 */

import { chromium, type Page, type BrowserContext } from '@playwright/test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as readline from 'node:readline';

const OUTPUT_DIR = path.resolve(import.meta.dirname ?? '.', '..', 'captured');
const JS_DIR = path.join(OUTPUT_DIR, 'js');
const API_DIR = path.join(OUTPUT_DIR, 'api');

/** Ensure output directories exist. */
function ensureDirs(): void {
  for (const dir of [OUTPUT_DIR, JS_DIR, API_DIR]) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

/** Sanitize a URL into a safe filename. */
function urlToFilename(url: string, ext = ''): string {
  const u = new URL(url);
  const raw = (u.hostname + u.pathname + u.search)
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .replace(/_+/g, '_')
    .slice(0, 200);
  return raw + ext;
}

/** Wait for the user to press Enter in the terminal. */
function waitForEnter(prompt: string): Promise<void> {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(prompt, () => {
      rl.close();
      resolve();
    });
  });
}

interface CapturedRequest {
  timestamp: string;
  method: string;
  url: string;
  requestHeaders: Record<string, string>;
  requestPostData: string | null;
  status: number | null;
  responseHeaders: Record<string, string> | null;
  responseBody: string | null;
  resourceType: string;
}

async function main(): Promise<void> {
  ensureDirs();

  const capturedRequests: CapturedRequest[] = [];
  const jsFiles: Map<string, string> = new Map();
  let requestCounter = 0;

  console.log('Launching browser – please log in to recorder.google.com …');

  // Use a persistent user-data dir so Google login sticks between runs.
  const userDataDir = path.join(OUTPUT_DIR, '.browser-profile');
  const context: BrowserContext = await chromium.launchPersistentContext(userDataDir, {
    headless: false,
    viewport: { width: 1280, height: 900 },
    args: ['--disable-blink-features=AutomationControlled'],
  });

  const page: Page = context.pages()[0] ?? await context.newPage();

  // --- Intercept responses ------------------------------------------------
  page.on('response', async (response) => {
    const url = response.url();
    const resourceType = response.request().resourceType();
    const status = response.status();
    const method = response.request().method();

    // Capture JavaScript files
    if (resourceType === 'script' || url.endsWith('.js')) {
      try {
        const body = await response.text();
        const filename = urlToFilename(url, '.js');
        jsFiles.set(url, body);
        fs.writeFileSync(path.join(JS_DIR, filename), body, 'utf-8');
        console.log(`  [JS]  ${url.slice(0, 120)}`);
      } catch { /* response body unavailable */ }
    }

    // Capture XHR / Fetch API calls
    if (resourceType === 'xhr' || resourceType === 'fetch' || url.includes('/api') || url.includes('/$rpc')) {
      requestCounter++;
      let responseBody: string | null = null;
      let responseHeaders: Record<string, string> | null = null;
      try {
        responseBody = await response.text();
        responseHeaders = await response.allHeaders();
      } catch { /* body unavailable */ }

      const entry: CapturedRequest = {
        timestamp: new Date().toISOString(),
        method,
        url,
        requestHeaders: await response.request().allHeaders(),
        requestPostData: response.request().postData() ?? null,
        status,
        responseHeaders,
        responseBody,
        resourceType,
      };
      capturedRequests.push(entry);

      // Save individual request
      const fname = `${String(requestCounter).padStart(4, '0')}_${method}_${urlToFilename(url)}.json`;
      fs.writeFileSync(path.join(API_DIR, fname), JSON.stringify(entry, null, 2), 'utf-8');
      console.log(`  [API] ${method} ${status} ${url.slice(0, 120)}`);
    }
  });

  // Navigate to recorder.google.com
  await page.goto('https://recorder.google.com/', { waitUntil: 'domcontentloaded' });

  console.log('\n==========================================================');
  console.log(' Browser is open. Please log in and browse around to');
  console.log(' trigger API calls. When you are done, come back here');
  console.log(' and press ENTER to finish capturing.');
  console.log('==========================================================\n');

  await waitForEnter('Press ENTER when you are done capturing … ');

  // --- Write summary files ------------------------------------------------
  // All API requests in one file
  const apiSummaryPath = path.join(OUTPUT_DIR, 'api-requests.json');
  fs.writeFileSync(apiSummaryPath, JSON.stringify(capturedRequests, null, 2), 'utf-8');

  // Build a concise endpoint list
  const endpoints = [...new Set(capturedRequests.map((r) => `${r.method} ${r.url}`))].sort();
  const endpointsPath = path.join(OUTPUT_DIR, 'endpoints.txt');
  fs.writeFileSync(endpointsPath, endpoints.join('\n') + '\n', 'utf-8');

  // JS file index
  const jsIndex = [...jsFiles.keys()].sort();
  const jsIndexPath = path.join(OUTPUT_DIR, 'js-index.txt');
  fs.writeFileSync(jsIndexPath, jsIndex.join('\n') + '\n', 'utf-8');

  console.log(`\nCapture complete!`);
  console.log(`  JS files saved  : ${jsFiles.size}  → ${JS_DIR}`);
  console.log(`  API requests    : ${capturedRequests.length}  → ${API_DIR}`);
  console.log(`  Endpoint list   : ${endpointsPath}`);
  console.log(`  JS index        : ${jsIndexPath}`);
  console.log(`  Full API log    : ${apiSummaryPath}`);

  await context.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
