const STORAGE_KEY = "fileJarvisMvpState";

const defaultState = {
  selectedProjectId: "design-refresh",
  activeDetail: "access",
  scope: [
    {
      id: "design-docs",
      name: "Design Docs",
      path: "~/Projects/Brand Refresh",
      approved: true,
      description: "Roadmaps, decks, wireframes, and planning notes.",
    },
    {
      id: "screenshots",
      name: "Screenshots",
      path: "~/Desktop/Screenshots",
      approved: true,
      description: "Usually the fastest place to reduce clutter and create momentum.",
    },
    {
      id: "finance",
      name: "Finance",
      path: "~/Documents/Finance",
      approved: false,
      description: "Sensitive budgets and invoices stay outside Jarvis until allowed.",
    },
  ],
  files: [
    {
      id: "f1",
      name: "Q3-roadmap-v5.pdf",
      folderId: "design-docs",
      projectId: "design-refresh",
      kind: "PDF",
      summary: "Latest roadmap draft with launch sequencing and owner notes.",
      tags: ["roadmap", "planning", "latest"],
      modified: "2h ago",
    },
    {
      id: "f2",
      name: "landing-page-wireframe.fig",
      folderId: "design-docs",
      projectId: "design-refresh",
      kind: "Design",
      summary: "Wireframe with annotation threads around CTA hierarchy.",
      tags: ["design", "wireframe"],
      modified: "Yesterday",
    },
    {
      id: "f3",
      name: "Screenshot 2026-07-18 at 10.42.11.png",
      folderId: "screenshots",
      projectId: "research-vault",
      kind: "Image",
      summary: "Pricing screenshot saved without context in the file name.",
      tags: ["screenshot", "pricing", "rename"],
      modified: "1d ago",
    },
    {
      id: "f4",
      name: "research-notes-clutter.md",
      folderId: "screenshots",
      projectId: "research-vault",
      kind: "Markdown",
      summary: "Working note that should probably stay linked to screenshot cleanup.",
      tags: ["notes", "research"],
      modified: "4h ago",
    },
    {
      id: "f5",
      name: "budget-draft.xlsx",
      folderId: "finance",
      projectId: "ops-admin",
      kind: "Spreadsheet",
      summary: "Monthly budget sheet hidden until Finance is approved.",
      tags: ["budget", "sensitive"],
      modified: "3d ago",
    },
  ],
  profile: {
    tone: "Concise, practical, and calm",
    chaos: "Okay with a little mess, but prefers clear next steps",
    naming: "Date-first for deliverables, plain-language folders",
    focus: "Reduce screenshot clutter without losing project context",
  },
  projects: [
    {
      id: "design-refresh",
      name: "Brand Refresh",
      summary: "Launch docs, wireframes, and decisions stay grouped together.",
    },
    {
      id: "research-vault",
      name: "Research Vault",
      summary: "Screenshots and notes are treated as one cleanup stream.",
    },
    {
      id: "ops-admin",
      name: "Ops and Admin",
      summary: "Sensitive files stay invisible unless explicitly approved.",
    },
  ],
  chats: [
    {
      role: "assistant",
      text: "I stay scoped to approved folders. Start with access, then ask for help, then open a section only if you want more detail.",
    },
  ],
};

const detailConfig = {
  access: {
    eyebrow: "Access",
    title: "Current permissions and folders",
    description: "This is the explicit access layer. If a folder is blocked here, Jarvis should treat it as fully out of scope.",
  },
  find: {
    eyebrow: "Find files",
    title: "Search inside approved scope",
    description: "Browse only what Jarvis can currently see. This section stays one level deeper so search does not dominate the home view.",
  },
  organize: {
    eyebrow: "Organize",
    title: "Cleanup suggestions before action",
    description: "A higher-level view of what looks messy, repetitive, or worth organizing next.",
  },
  project: {
    eyebrow: "Project context",
    title: "Project-linked file context",
    description: "Choose the current project so Jarvis can bias search and suggestions toward the right workstream.",
  },
  profile: {
    eyebrow: "Work Style Profile",
    title: "How Jarvis should help",
    description: "A lightweight memory layer so the assistant adapts without becoming invasive.",
  },
};

function loadState() {
  const saved = window.localStorage.getItem(STORAGE_KEY);
  if (!saved) {
    return structuredClone(defaultState);
  }

  try {
    return { ...structuredClone(defaultState), ...JSON.parse(saved) };
  } catch {
    return structuredClone(defaultState);
  }
}

const state = loadState();

const elements = {
  chatForm: document.querySelector("#chat-form"),
  chatInput: document.querySelector("#chat-input"),
  chatLog: document.querySelector("#chat-log"),
  scopePill: document.querySelector("#scope-pill"),
  closeDrawer: document.querySelector("#close-drawer"),
  detailDrawer: document.querySelector("#detail-drawer"),
  contextStrip: document.querySelector("#context-strip"),
  accessSummary: document.querySelector("#access-summary"),
  detailEyebrow: document.querySelector("#detail-eyebrow"),
  detailTitle: document.querySelector("#detail-title"),
  detailDescription: document.querySelector("#detail-description"),
  detailContent: document.querySelector("#detail-content"),
  findSummary: document.querySelector("#find-summary"),
  organizeSummary: document.querySelector("#organize-summary"),
  projectSummaryCard: document.querySelector("#project-summary-card"),
  profileSummaryCard: document.querySelector("#profile-summary-card"),
  quickPromptButtons: [...document.querySelectorAll(".chip-button")],
  detailButtons: [...document.querySelectorAll("[data-detail-target]")],
};

function saveState() {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function getApprovedFolders() {
  return state.scope.filter((folder) => folder.approved);
}

function getBlockedFolders() {
  return state.scope.filter((folder) => !folder.approved);
}

function getVisibleFiles() {
  const approvedIds = new Set(getApprovedFolders().map((folder) => folder.id));
  return state.files.filter((file) => approvedIds.has(file.folderId));
}

function getCurrentProject() {
  return state.projects.find((project) => project.id === state.selectedProjectId);
}

function openDetail(name) {
  state.activeDetail = name;
  renderDetailDrawer();
  elements.detailDrawer.classList.add("open");
  elements.detailDrawer.setAttribute("aria-hidden", "false");
  saveState();
}

function closeDetail() {
  elements.detailDrawer.classList.remove("open");
  elements.detailDrawer.setAttribute("aria-hidden", "true");
}

function renderContextStrip() {
  const approved = getApprovedFolders();
  const blocked = getBlockedFolders();
  const project = getCurrentProject();
  const visibleFiles = getVisibleFiles();

  elements.contextStrip.innerHTML = `
    <button class="context-chip" data-detail-target="access" type="button">${approved.length} approved folder${approved.length === 1 ? "" : "s"}</button>
    <button class="context-chip" data-detail-target="access" type="button">${blocked.length} blocked</button>
    <button class="context-chip" data-detail-target="find" type="button">${visibleFiles.length} visible file${visibleFiles.length === 1 ? "" : "s"}</button>
    <button class="context-chip" data-detail-target="project" type="button">Project: ${project.name}</button>
  `;

  elements.contextStrip.querySelectorAll("[data-detail-target]").forEach((button) => {
    button.addEventListener("click", () => openDetail(button.dataset.detailTarget));
  });
}

function renderAccessSummary() {
  const approved = getApprovedFolders();
  const blocked = getBlockedFolders();
  const visibleFiles = getVisibleFiles();

  elements.accessSummary.innerHTML = `
    <div class="access-main-stat">${approved.length} approved folder${approved.length === 1 ? "" : "s"}</div>
    <div class="access-pill-row">
      <span class="access-pill">${visibleFiles.length} visible file${visibleFiles.length === 1 ? "" : "s"}</span>
      <span class="access-pill">${blocked.length} blocked folder${blocked.length === 1 ? "" : "s"}</span>
    </div>
    <div class="access-list">
      ${state.scope
        .map(
          (folder) => `
            <div class="access-row">
              <div>
                <strong>${folder.name}</strong>
                <div class="folder-line">${folder.path}</div>
              </div>
              <span class="status-label ${folder.approved ? "approved" : "blocked"}">
                ${folder.approved ? "Approved" : "Blocked"}
              </span>
            </div>
          `
        )
        .join("")}
    </div>
  `;
}

function renderChat() {
  elements.chatLog.innerHTML = state.chats
    .map(
      (message) => `
        <div class="chat-message ${message.role}">
          ${message.text}
        </div>
      `
    )
    .join("");
  elements.chatLog.scrollTop = elements.chatLog.scrollHeight;
}

function renderSectionSummaries() {
  const visibleFiles = getVisibleFiles();
  const currentProject = getCurrentProject();
  const screenshotFiles = visibleFiles.filter((file) => file.folderId === "screenshots");

  elements.findSummary.textContent = `${visibleFiles.length} visible file${visibleFiles.length === 1 ? "" : "s"} in scope.`;
  elements.organizeSummary.textContent = screenshotFiles.length
    ? `${screenshotFiles.length} screenshot item${screenshotFiles.length === 1 ? "" : "s"} to clean first.`
    : "No clear cleanup target visible.";
  elements.projectSummaryCard.textContent = `${currentProject.name} is active.`;
  elements.profileSummaryCard.textContent = `${state.profile.tone}.`;
}

function buildAssistantReply(input) {
  const text = input.toLowerCase();
  const visibleFiles = getVisibleFiles();
  const approvedNames = getApprovedFolders().map((folder) => folder.name);
  const project = getCurrentProject();
  const trimmed = text.trim();

  if (["hi", "hello", "hey", "hiya"].includes(trimmed)) {
    return `Hi. I can currently see ${approvedNames.join(", ") || "no folders yet"}. If you want, I can help find a file, explain what is in scope, or suggest a cleanup starting point.`;
  }

  if (trimmed.includes("help")) {
    return "I can help you check access, find a file in approved folders, suggest what to organize first, or stay focused on the current project.";
  }

  if (text.includes("see") || text.includes("scope") || text.includes("access")) {
    return `I can currently see ${approvedNames.join(", ") || "no folders yet"}. That gives me ${visibleFiles.length} visible file${visibleFiles.length === 1 ? "" : "s"} to work with.`;
  }

  if (text.includes("screenshot") || text.includes("clean")) {
    const screenshotFiles = visibleFiles.filter((file) => file.folderId === "screenshots");
    return `The cleanest first move is the screenshots area. I can see ${screenshotFiles.length} screenshot-related file${screenshotFiles.length === 1 ? "" : "s"}, and I’d rename the high-value ones before attempting a bigger re-org.`;
  }

  if (text.includes("roadmap") || text.includes("find")) {
    const roadmapMatch = visibleFiles.find((file) =>
      [file.name, file.summary, file.tags.join(" ")].join(" ").toLowerCase().includes("roadmap")
    );
    return roadmapMatch
      ? `The strongest visible roadmap match is ${roadmapMatch.name}. I’m biasing toward ${project.name} because that project is active right now.`
      : "I do not see a roadmap file inside the currently approved scope.";
  }

  if (text.includes("project") || text.includes("context")) {
    return `You’re currently anchored to ${project.name}. The goal is to keep that context present without forcing you into a separate project-management flow.`;
  }

  return `I’m not fully sure what you want yet, but I can help with access, finding files, cleanup suggestions, or project context. Right now I’m scoped to ${approvedNames.join(", ") || "no folders yet"}.`;
}

function handlePrompt(text) {
  if (!text) {
    return;
  }

  state.chats.push({ role: "user", text });
  state.chats.push({ role: "assistant", text: buildAssistantReply(text) });
  saveState();
  renderChat();
}

function renderAccessDetail() {
  elements.detailContent.innerHTML = `
    <div class="scope-detail-list">
      ${state.scope
        .map(
          (folder) => `
            <div class="scope-row">
              <div>
                <strong>${folder.name}</strong>
                <p>${folder.path}</p>
                <p class="detail-note">${folder.description}</p>
              </div>
              <button class="scope-toggle ${folder.approved ? "enabled" : "disabled"}" data-folder-id="${folder.id}">
                ${folder.approved ? "Approved" : "Blocked"}
              </button>
            </div>
          `
        )
        .join("")}
    </div>
  `;
}

function renderFindDetail() {
  const visibleFiles = getVisibleFiles();
  elements.detailContent.innerHTML = `
    <div class="detail-list">
      ${visibleFiles
        .map(
          (file) => `
            <article class="result-card">
              <strong>${file.name}</strong>
              <p>${file.summary}</p>
              <div class="meta-row">
                <span class="meta-pill">${file.kind}</span>
                <span class="meta-pill">${file.modified}</span>
                ${file.tags.map((tag) => `<span class="meta-pill">${tag}</span>`).join("")}
              </div>
            </article>
          `
        )
        .join("")}
    </div>
  `;
}

function renderOrganizeDetail() {
  const visibleFiles = getVisibleFiles();
  const screenshotFiles = visibleFiles.filter((file) => file.folderId === "screenshots");
  const roadmapFiles = visibleFiles.filter((file) => file.folderId === "design-docs");

  elements.detailContent.innerHTML = `
    <div class="detail-list">
      <div class="organize-tip">
        <strong>Start with screenshots</strong>
        <p>${screenshotFiles.length} screenshot-related file${screenshotFiles.length === 1 ? "" : "s"} are visible. This is the fastest low-risk cleanup area.</p>
      </div>
      <div class="organize-tip">
        <strong>Keep roadmap work grouped</strong>
        <p>${roadmapFiles.length} project file${roadmapFiles.length === 1 ? "" : "s"} sit in the design scope. Jarvis should keep these tied to Brand Refresh instead of mixing them with general clutter.</p>
      </div>
      <div class="organize-tip">
        <strong>Leave blocked folders alone</strong>
        <p>Finance stays out of all organization suggestions until you explicitly approve it.</p>
      </div>
    </div>
  `;
}

function renderProjectDetail() {
  const currentProject = getCurrentProject();
  elements.detailContent.innerHTML = `
    <div class="detail-list">
      <div class="organize-tip">
        <strong>Current project</strong>
        <p>${currentProject.name}: ${currentProject.summary}</p>
      </div>
      <div class="project-list">
        ${state.projects
          .map(
            (project) => `
              <button class="project-button ${project.id === state.selectedProjectId ? "active" : ""}" data-project-id="${project.id}">
                ${project.name}
              </button>
            `
          )
          .join("")}
      </div>
    </div>
  `;
}

function renderProfileDetail() {
  elements.detailContent.innerHTML = `
    <div class="detail-list">
      <div class="organize-tip">
        <strong>Tone</strong>
        <p>${state.profile.tone}</p>
      </div>
      <div class="organize-tip">
        <strong>Mess tolerance</strong>
        <p>${state.profile.chaos}</p>
      </div>
      <div class="organize-tip">
        <strong>Naming preference</strong>
        <p>${state.profile.naming}</p>
      </div>
      <div class="organize-tip">
        <strong>Current focus</strong>
        <p>${state.profile.focus}</p>
      </div>
    </div>
  `;
}

function wireDetailButtons() {
  document.querySelectorAll("[data-folder-id]").forEach((button) => {
    button.addEventListener("click", () => {
      const folder = state.scope.find((item) => item.id === button.dataset.folderId);
      folder.approved = !folder.approved;
      saveState();
      renderAll();
      renderDetailDrawer();
    });
  });

  document.querySelectorAll("[data-project-id]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedProjectId = button.dataset.projectId;
      saveState();
      renderAll();
      renderDetailDrawer();
    });
  });
}

function renderDetailDrawer() {
  const config = detailConfig[state.activeDetail];
  elements.detailEyebrow.textContent = config.eyebrow;
  elements.detailTitle.textContent = config.title;
  elements.detailDescription.textContent = config.description;

  if (state.activeDetail === "access") {
    renderAccessDetail();
  } else if (state.activeDetail === "find") {
    renderFindDetail();
  } else if (state.activeDetail === "organize") {
    renderOrganizeDetail();
  } else if (state.activeDetail === "project") {
    renderProjectDetail();
  } else if (state.activeDetail === "profile") {
    renderProfileDetail();
  }

  wireDetailButtons();
}

function renderAll() {
  renderContextStrip();
  renderAccessSummary();
  renderSectionSummaries();
  renderChat();
}

elements.chatForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const text = elements.chatInput.value.trim();
  handlePrompt(text);
  elements.chatInput.value = "";
});

elements.quickPromptButtons.forEach((button) => {
  button.addEventListener("click", () => handlePrompt(button.dataset.prompt));
});

elements.scopePill.addEventListener("click", () => openDetail("access"));
elements.detailButtons.forEach((button) => {
  button.addEventListener("click", () => openDetail(button.dataset.detailTarget));
});
elements.closeDrawer.addEventListener("click", closeDetail);
elements.detailDrawer.querySelector(".drawer-backdrop").addEventListener("click", closeDetail);

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeDetail();
  }
});

renderAll();
