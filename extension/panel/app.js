"use strict";
(() => {
  // src/services/mock-api-client.ts
  var MOCK_RECORDINGS = [
    {
      id: "1",
      name: "2026-02-16 (Alice): Project Kickoff",
      date: /* @__PURE__ */ new Date("2026-02-16T15:30:00Z"),
      duration: 2723,
      speakers: [
        { id: "s1", name: "Mark" },
        { id: "s2", name: "Alice" }
      ],
      transcript: [
        { speakerId: "s1", speakerName: "Mark", text: "Let's discuss the project timeline.", startTime: 0, endTime: 8 },
        { speakerId: "s2", speakerName: "Alice", text: "I think we need about two weeks for the initial phase.", startTime: 8, endTime: 15 },
        { speakerId: "s1", speakerName: "Mark", text: "That works. What about the design sprint?", startTime: 15, endTime: 22 },
        { speakerId: "s2", speakerName: "Alice", text: "We should plan for a week of design work before implementation.", startTime: 22, endTime: 30 }
      ]
    },
    {
      id: "2",
      name: "Team Standup",
      date: /* @__PURE__ */ new Date("2026-02-15T09:00:00Z"),
      duration: 725,
      speakers: [
        { id: "s1", name: "Mark" }
      ],
      transcript: [
        { speakerId: "s1", speakerName: "Mark", text: "Yesterday I finished the API integration.", startTime: 0, endTime: 5 },
        { speakerId: "s1", speakerName: "Mark", text: "Today I'll work on the UI components.", startTime: 5, endTime: 10 }
      ]
    },
    {
      id: "3",
      name: "Feb 14, 2026 2:30 PM",
      date: /* @__PURE__ */ new Date("2026-02-14T14:30:00Z"),
      duration: 1812,
      speakers: [
        { id: "s1", name: "Mark" },
        { id: "s3", name: "Bob" }
      ],
      transcript: [
        { speakerId: "s1", speakerName: "Mark", text: "Let's review the budget for Q2.", startTime: 0, endTime: 6 },
        { speakerId: "s3", speakerName: "Bob", text: "Sure, I have the numbers ready.", startTime: 6, endTime: 10 },
        { speakerId: "s3", speakerName: "Bob", text: "We're looking at a 15% increase over last quarter.", startTime: 10, endTime: 18 },
        { speakerId: "s1", speakerName: "Mark", text: "That's within our projected range.", startTime: 18, endTime: 23 }
      ]
    },
    {
      id: "4",
      name: "2026-02-13 (Alice, Charlie): Sprint Planning",
      date: /* @__PURE__ */ new Date("2026-02-13T10:00:00Z"),
      duration: 3600,
      speakers: [
        { id: "s1", name: "Mark" },
        { id: "s2", name: "Alice" },
        { id: "s4", name: "Charlie" }
      ],
      transcript: [
        { speakerId: "s1", speakerName: "Mark", text: "Welcome to sprint planning. Let's prioritize the backlog.", startTime: 0, endTime: 8 },
        { speakerId: "s2", speakerName: "Alice", text: "I suggest we focus on the auth module first.", startTime: 8, endTime: 14 },
        { speakerId: "s4", speakerName: "Charlie", text: "Agreed. I can take the database migration tasks.", startTime: 14, endTime: 22 }
      ]
    }
  ];
  var MockApiClient = class {
    recordings = [...MOCK_RECORDINGS];
    /**
     * Returns all mock recordings.
     */
    async listRecordings() {
      return [...this.recordings];
    }
    /**
     * Returns a single mock recording by ID.
     */
    async getRecording(id) {
      const recording = this.recordings.find((r) => r.id === id);
      if (!recording) {
        throw new Error(`Recording not found: ${id}`);
      }
      return recording;
    }
    /**
     * Renames a mock recording.
     */
    async renameRecording(id, newName) {
      const recording = this.recordings.find((r) => r.id === id);
      if (!recording) {
        throw new Error(`Recording not found: ${id}`);
      }
      recording.name = newName;
    }
  };

  // src/utils/auto-rename.ts
  var DATE_TIME_PATTERNS = [
    /^\w{3}\s+\d{1,2},\s+\d{4}\s+\d{1,2}:\d{2}\s*(AM|PM)$/i,
    /^\d{4}-\d{2}-\d{2}\s+\d{1,2}:\d{2}$/,
    /^\d{1,2}\/\d{1,2}\/\d{4}\s+\d{1,2}:\d{2}\s*(AM|PM)$/i
  ];
  function isDateTimeName(name) {
    return DATE_TIME_PATTERNS.some((pattern) => pattern.test(name.trim()));
  }
  function extractParticipantsFromName(name) {
    const match = name.match(/\(([^)]+)\)/);
    return match ? match[1].trim() : null;
  }
  function extractTitleFromName(name) {
    const colonIndex = name.indexOf(":");
    if (colonIndex === -1) return null;
    const afterColon = name.substring(colonIndex + 1).trim();
    return afterColon.length > 0 ? afterColon : null;
  }
  function generateTitleFromTranscript(transcript) {
    if (transcript.length === 0) return "Untitled Recording";
    const firstSegment = transcript[0].text.trim();
    if (!firstSegment) return "Untitled Recording";
    const words = firstSegment.split(/\s+/).slice(0, 6);
    const title = words.join(" ");
    return title.endsWith(".") ? title.slice(0, -1) : title;
  }
  function formatDate(date) {
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, "0");
    const day = String(date.getUTCDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }
  function buildParticipants(speakers, ownerName) {
    return speakers.filter((s) => s.name !== ownerName).map((s) => s.name).join(", ");
  }
  function generateAutoName(recording, ownerName) {
    const datePart = formatDate(recording.date);
    const existingParticipants = extractParticipantsFromName(recording.name);
    const participantStr = existingParticipants ?? buildParticipants(recording.speakers, ownerName);
    let title;
    const existingTitle = extractTitleFromName(recording.name);
    if (existingTitle && !isDateTimeName(recording.name)) {
      title = existingTitle;
    } else if (isDateTimeName(recording.name)) {
      title = generateTitleFromTranscript(recording.transcript);
    } else {
      title = recording.name;
    }
    if (participantStr.length > 0) {
      return `${datePart} (${participantStr}): ${title}`;
    }
    return `${datePart}: ${title}`;
  }

  // src/services/recording-service.ts
  var RecordingService = class {
    api;
    ownerName;
    constructor(api, ownerName) {
      this.api = api;
      this.ownerName = ownerName;
    }
    /**
     * Fetches all recordings, sorted by date descending.
     */
    async getRecordings() {
      const recordings = await this.api.listRecordings();
      return recordings.sort(
        (a, b) => b.date.getTime() - a.date.getTime()
      );
    }
    /**
     * Renames a recording to the given name.
     */
    async renameRecording(id, newName) {
      await this.api.renameRecording(id, newName);
    }
    /**
     * Generates the auto-rename for a recording without applying it.
     */
    previewAutoRename(recording) {
      return generateAutoName(recording, this.ownerName);
    }
    /**
     * Generates and applies the auto-rename for a recording.
     */
    async autoRenameRecording(recording) {
      const newName = generateAutoName(recording, this.ownerName);
      await this.api.renameRecording(recording.id, newName);
      return { id: recording.id, originalName: recording.name, newName };
    }
    /**
     * Auto-renames all provided recordings.
     */
    async autoRenameAll(recordings) {
      const results = [];
      for (const recording of recordings) {
        const result = await this.autoRenameRecording(recording);
        results.push(result);
      }
      return results;
    }
  };

  // src/utils/dom-helpers.ts
  function toErrorMessage(err) {
    return err instanceof Error ? err.message : "Unknown error";
  }
  function queryRequired(selector, parent = document) {
    const el = parent.querySelector(selector);
    if (!el) {
      throw new Error(`Required element not found: ${selector}`);
    }
    return el;
  }

  // src/ui/recordings-ui.ts
  function formatDuration(seconds) {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor(seconds % 3600 / 60);
    const secs = Math.floor(seconds % 60);
    if (hours > 0) {
      return `${hours}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
    }
    return `${mins}:${String(secs).padStart(2, "0")}`;
  }
  function formatDisplayDate(date) {
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric"
    });
  }
  var RecordingsUI = class {
    service;
    recordingListEl;
    loadingEl;
    errorEl;
    errorMsgEl;
    retryBtn;
    renameAllBtn;
    itemTemplate;
    segmentTemplate;
    recordings = [];
    constructor(service) {
      this.service = service;
      this.recordingListEl = queryRequired("#recording-list");
      this.loadingEl = queryRequired("#loading");
      this.errorEl = queryRequired("#error");
      this.errorMsgEl = queryRequired("#error-message");
      this.retryBtn = queryRequired("#retry-btn");
      this.renameAllBtn = queryRequired("#rename-all-btn");
      this.itemTemplate = queryRequired("#recording-item-template");
      this.segmentTemplate = queryRequired("#transcript-segment-template");
      this.retryBtn.addEventListener("click", () => this.loadRecordings());
      this.renameAllBtn.addEventListener("click", () => this.handleRenameAll());
    }
    /** Initializes the UI by loading recordings. */
    async init() {
      await this.loadRecordings();
    }
    /** Loads recordings and renders the list. */
    async loadRecordings() {
      this.showLoading();
      try {
        this.recordings = await this.service.getRecordings();
        this.render();
      } catch (err) {
        this.showError(toErrorMessage(err));
      }
    }
    /** Renders all recordings to the list. */
    render() {
      this.loadingEl.hidden = true;
      this.errorEl.hidden = true;
      this.recordingListEl.innerHTML = "";
      for (const recording of this.recordings) {
        const item = this.createRecordingItem(recording);
        this.recordingListEl.appendChild(item);
      }
    }
    /** Creates a DOM element for a single recording. */
    createRecordingItem(recording) {
      const fragment = this.itemTemplate.content.cloneNode(true);
      const li = queryRequired(".recording-item", fragment);
      li.dataset.id = recording.id;
      this.populateRecordingData(li, recording);
      this.bindRecordingEvents(li, recording);
      return li;
    }
    /** Populates the static data fields of a recording item. */
    populateRecordingData(li, recording) {
      queryRequired(".recording-name", li).textContent = recording.name;
      queryRequired(".recording-date", li).textContent = formatDisplayDate(recording.date);
      queryRequired(".recording-duration", li).textContent = formatDuration(recording.duration);
      queryRequired(".recording-speakers", li).textContent = recording.speakers.map((s) => s.name).join(", ");
    }
    /** Binds all event listeners on a recording item. */
    bindRecordingEvents(li, recording) {
      const header = queryRequired(".recording-header", li);
      header.addEventListener("click", () => this.toggleExpand(li, recording));
      header.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          this.toggleExpand(li, recording);
        }
      });
      queryRequired(".btn-rename", li).addEventListener("click", () => this.showRenameForm(li, recording));
      queryRequired(".btn-auto-rename", li).addEventListener("click", () => this.showAutoRenamePreview(li, recording));
      queryRequired(".btn-save", li).addEventListener("click", () => this.handleSaveRename(li, recording));
      queryRequired(".btn-cancel", li).addEventListener("click", () => this.hideRenameForm(li));
      queryRequired(".btn-confirm", li).addEventListener("click", () => this.handleConfirmAutoRename(li, recording));
      queryRequired(".btn-cancel-preview", li).addEventListener("click", () => this.hideAutoRenamePreview(li));
    }
    /** Updates the displayed name of a recording in the DOM. */
    updateRecordingName(li, recording, newName) {
      recording.name = newName;
      queryRequired(".recording-name", li).textContent = newName;
    }
    /** Toggles the expanded state of a recording item. */
    toggleExpand(li, recording) {
      const isExpanded = li.classList.toggle("expanded");
      queryRequired(".recording-header", li).setAttribute("aria-expanded", String(isExpanded));
      queryRequired(".recording-transcript", li).hidden = !isExpanded;
      if (isExpanded) {
        this.renderTranscript(li, recording.transcript);
      }
    }
    /** Renders transcript segments into a recording item. */
    renderTranscript(li, segments) {
      const container = queryRequired(".transcript-segments", li);
      container.innerHTML = "";
      for (const segment of segments) {
        const frag = this.segmentTemplate.content.cloneNode(true);
        const segEl = queryRequired(".transcript-segment", frag);
        queryRequired(".segment-speaker", segEl).textContent = `${segment.speakerName}:`;
        queryRequired(".segment-text", segEl).textContent = segment.text;
        container.appendChild(segEl);
      }
      if (segments.length === 0) {
        container.textContent = "No transcript available.";
      }
    }
    /** Shows the rename form for a recording. */
    showRenameForm(li, recording) {
      const form = queryRequired(".recording-rename-form", li);
      const input = queryRequired(".rename-input", form);
      form.hidden = false;
      input.value = recording.name;
      input.focus();
    }
    /** Hides the rename form. */
    hideRenameForm(li) {
      queryRequired(".recording-rename-form", li).hidden = true;
    }
    /** Handles saving a manual rename. */
    async handleSaveRename(li, recording) {
      const form = queryRequired(".recording-rename-form", li);
      const input = queryRequired(".rename-input", form);
      const newName = input.value.trim();
      if (!newName) return;
      try {
        await this.service.renameRecording(recording.id, newName);
        this.updateRecordingName(li, recording, newName);
        form.hidden = true;
      } catch (err) {
        alert(`Failed to rename: ${toErrorMessage(err)}`);
      }
    }
    /** Shows the auto-rename preview. */
    showAutoRenamePreview(li, recording) {
      const preview = queryRequired(".recording-preview", li);
      queryRequired(".preview-name", preview).textContent = this.service.previewAutoRename(recording);
      preview.hidden = false;
    }
    /** Hides the auto-rename preview. */
    hideAutoRenamePreview(li) {
      queryRequired(".recording-preview", li).hidden = true;
    }
    /** Confirms and applies the auto-rename. */
    async handleConfirmAutoRename(li, recording) {
      try {
        const result = await this.service.autoRenameRecording(recording);
        this.updateRecordingName(li, recording, result.newName);
        this.hideAutoRenamePreview(li);
      } catch (err) {
        alert(`Failed to auto-rename: ${toErrorMessage(err)}`);
      }
    }
    /** Renames all recordings with auto-rename. */
    async handleRenameAll() {
      const btn = this.renameAllBtn;
      btn.disabled = true;
      btn.textContent = "Renaming\u2026";
      try {
        const results = await this.service.autoRenameAll(this.recordings);
        for (const result of results) {
          const recording = this.recordings.find((r) => r.id === result.id);
          if (recording) {
            recording.name = result.newName;
          }
        }
        this.render();
      } catch (err) {
        alert(`Failed to rename all: ${toErrorMessage(err)}`);
      } finally {
        btn.disabled = false;
        btn.textContent = "Rename All";
      }
    }
    /** Shows the loading indicator. */
    showLoading() {
      this.loadingEl.hidden = false;
      this.errorEl.hidden = true;
      this.recordingListEl.innerHTML = "";
    }
    /** Shows an error message. */
    showError(message) {
      this.loadingEl.hidden = true;
      this.errorEl.hidden = false;
      this.errorMsgEl.textContent = message;
    }
  };

  // src/services/extension-api-client.ts
  async function extensionFetch(url, method = "GET", body) {
    const message = {
      type: "GRC_FETCH",
      payload: { url, method, body }
    };
    const response = await chrome.runtime.sendMessage(message);
    if (!response.ok) {
      throw new Error(response.error ?? "Extension fetch failed");
    }
    return response.data;
  }
  var ExtensionApiClient = class {
    /**
     * Retrieves all intercepted network requests captured by the
     * content script. Use this to discover the real API endpoints.
     */
    async discoverEndpoints() {
      const response = await chrome.runtime.sendMessage({
        type: "GRC_GET_CAPTURED"
      });
      return response?.captured ?? {};
    }
    /**
     * Lists all recordings for the authenticated user.
     * Uses the discovered API endpoint.
     */
    async listRecordings() {
      const data = await extensionFetch(
        "https://recorder.google.com/api/recordings"
      );
      return this.parseRecordings(data);
    }
    /**
     * Gets a single recording by ID.
     */
    async getRecording(id) {
      const data = await extensionFetch(
        `https://recorder.google.com/api/recordings/${id}`
      );
      return this.parseRecording(data);
    }
    /**
     * Renames a recording.
     */
    async renameRecording(id, newName) {
      await extensionFetch(
        `https://recorder.google.com/api/recordings/${id}`,
        "PATCH",
        { name: newName }
      );
    }
    /**
     * Parses raw API data into Recording objects.
     * This will be refined once we see the actual response format.
     */
    parseRecordings(data) {
      if (!Array.isArray(data)) {
        throw new Error(
          "Expected array of recordings. Run discoverEndpoints() to find the correct API format."
        );
      }
      return data.map((item) => this.parseRecording(item));
    }
    /**
     * Parses a single raw recording from the API response.
     */
    parseRecording(data) {
      const raw = data;
      return {
        id: String(raw["id"] ?? ""),
        name: String(raw["name"] ?? raw["title"] ?? "Untitled"),
        date: new Date(String(raw["date"] ?? raw["createdTime"] ?? raw["create_time"] ?? "")),
        duration: Number(raw["duration"] ?? raw["durationMs"] ?? 0) / (raw["durationMs"] ? 1e3 : 1),
        speakers: this.parseSpeakers(raw["speakers"] ?? raw["speakerLabels"] ?? []),
        transcript: this.parseTranscript(raw["transcript"] ?? raw["transcription"] ?? [])
      };
    }
    /**
     * Parses speakers from various possible API formats.
     */
    parseSpeakers(data) {
      if (!Array.isArray(data)) return [];
      return data.map((s, i) => ({
        id: String(s["id"] ?? s["speakerId"] ?? `speaker-${i}`),
        name: String(s["name"] ?? s["displayName"] ?? `Speaker ${i + 1}`)
      }));
    }
    /**
     * Parses transcript segments from various possible API formats.
     */
    parseTranscript(data) {
      if (!Array.isArray(data)) return [];
      return data.map((seg) => ({
        speakerId: String(seg["speakerId"] ?? seg["speaker_id"] ?? ""),
        speakerName: String(seg["speakerName"] ?? seg["speaker_name"] ?? ""),
        text: String(seg["text"] ?? seg["content"] ?? ""),
        startTime: Number(seg["startTime"] ?? seg["start_time"] ?? 0),
        endTime: Number(seg["endTime"] ?? seg["end_time"] ?? 0)
      }));
    }
  };

  // src/ui/discovery-panel.ts
  function initDiscoveryPanel(autoOpen = false) {
    const discoverBtn = document.getElementById("discover-btn");
    const panel = document.getElementById("discovery-panel");
    const output = document.getElementById("discovery-output");
    const refreshBtn = document.getElementById("discovery-refresh");
    const closeBtn = document.getElementById("discovery-close");
    if (!discoverBtn || !panel || !output || !refreshBtn || !closeBtn) {
      return;
    }
    const client = new ExtensionApiClient();
    const outputEl = output;
    async function refresh() {
      outputEl.textContent = "Loading captured requests\u2026";
      try {
        const endpoints = await client.discoverEndpoints();
        const keys = Object.keys(endpoints);
        if (keys.length === 0) {
          outputEl.textContent = "No requests captured yet.\n\nMake sure you have recorder.google.com open in a tab\nand navigate around to trigger API calls.";
          return;
        }
        const summary = keys.map((key) => {
          const entries = endpoints[key];
          const sample = entries[entries.length - 1];
          return [
            `\u2501\u2501 ${key} (${entries.length} call${entries.length > 1 ? "s" : ""}) \u2501\u2501`,
            `Status: ${sample.status}`,
            `Response: ${JSON.stringify(sample.body, null, 2).slice(0, 2e3)}`,
            ""
          ].join("\n");
        });
        outputEl.textContent = summary.join("\n");
      } catch (err) {
        outputEl.textContent = `Error: ${err instanceof Error ? err.message : String(err)}`;
      }
    }
    discoverBtn.addEventListener("click", () => {
      panel.hidden = !panel.hidden;
      if (!panel.hidden) {
        refresh().catch(console.error);
      }
    });
    refreshBtn.addEventListener("click", () => {
      refresh().catch(console.error);
    });
    closeBtn.addEventListener("click", () => {
      panel.hidden = true;
    });
    if (autoOpen) {
      panel.hidden = false;
      refresh().catch(console.error);
    }
  }

  // src/app.ts
  function isExtensionContext() {
    return typeof chrome !== "undefined" && !!chrome.runtime?.id;
  }
  function main() {
    const inExtension = isExtensionContext();
    const apiClient = new MockApiClient();
    const service = new RecordingService(apiClient, "Mark");
    const ui = new RecordingsUI(service);
    ui.init().catch(console.error);
    if (inExtension) {
      initDiscoveryPanel(true);
      console.log("[GRC] Running in extension mode \u2014 discovery panel auto-opened");
    } else {
      console.log("[GRC] Running in standalone mode \u2014 using mock data");
    }
  }
  document.addEventListener("DOMContentLoaded", main);
})();
//# sourceMappingURL=app.js.map
