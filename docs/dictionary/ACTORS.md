# All Actors (concurrency boundaries)

_26 entries_

_Each is a Sendable execution context._

- `AIService` -- [`GitMac/Core/Services/AIService.swift:4`](GitMac/Core/Services/AIService.swift)
  - AI Service for commit message generation and more
- `AvatarCache` -- [`GitMac/UI/Components/AvatarImageView.swift:7`](GitMac/UI/Components/AvatarImageView.swift)
- `AvatarService` -- [`GitMac/Core/Services/AvatarService.swift:9`](GitMac/Core/Services/AvatarService.swift)
  - Service to fetch and cache user avatars from Gravatar and GitHub
- `CloudPatchService` -- [`GitMac/Features/CloudPatches/CloudPatchService.swift:8`](GitMac/Features/CloudPatches/CloudPatchService.swift)
  - Service for creating and sharing code patches without committing
- `ConflictPreventionService` -- [`GitMac/Features/ConflictPrevention/ConflictPreventionService.swift:8`](GitMac/Features/ConflictPrevention/ConflictPreventionService.swift)
  - Service that detects potential merge conflicts BEFORE they happen
- `DiffCache` -- [`GitMac/Features/Diff/DiffCache.swift:7`](GitMac/Features/Diff/DiffCache.swift)
  - LRU cache for materialized diff hunks
- `DiffEngine` -- [`GitMac/Core/Git/DiffEngine.swift:210`](GitMac/Core/Git/DiffEngine.swift)
  - Actor for parsing and managing diffs with streaming support
- `DiffSearchEngine` -- [`GitMac/Features/Diff/DiffSearchEngine.swift:11`](GitMac/Features/Diff/DiffSearchEngine.swift)
  - Incremental search engine for diffs with on-demand materialization
- `GitHubOAuth` -- [`GitMac/Core/Services/GitHubOAuth.swift:7`](GitMac/Core/Services/GitHubOAuth.swift)
  - GitHub OAuth 2.0 with Device Flow
- `GitHubService` -- [`GitMac/Core/Services/GitHubService.swift:7`](GitMac/Core/Services/GitHubService.swift)
  - GitHub API service with caching, ETag support, and rate limit handling
- `GlobalDiffCache` -- [`GitMac/Features/Diff/DiffCache.swift:178`](GitMac/Features/Diff/DiffCache.swift)
- `IntralineDiffEngine` -- [`GitMac/Features/Diff/DiffEnhancements.swift:9`](GitMac/Features/Diff/DiffEnhancements.swift)
  - High-performance intraline diff with budget control
- `JiraService` -- [`GitMac/Core/Services/JiraService.swift:6`](GitMac/Core/Services/JiraService.swift)
  - Service to connect with Jira Cloud API
- `KeychainManager` -- [`GitMac/Core/Utils/KeychainManager.swift:8`](GitMac/Core/Utils/KeychainManager.swift)
  - Manages secure storage of credentials
- `LinearService` -- [`GitMac/Core/Services/LinearService.swift:6`](GitMac/Core/Services/LinearService.swift)
  - Service to connect with Linear API
- `MLXProvider` -- [`GitMac/Core/Services/AI/MLXProvider.swift:9`](GitMac/Core/Services/AI/MLXProvider.swift)
  - Native Apple Silicon AI provider using MLX framework.
- `MicrosoftOAuth` -- [`GitMac/Core/Services/MicrosoftOAuth.swift:7`](GitMac/Core/Services/MicrosoftOAuth.swift)
  - OAuth 2.0 Device Code Flow for Microsoft Graph API
- `MicrosoftPlannerService` -- [`GitMac/Core/Services/MicrosoftPlannerService.swift:6`](GitMac/Core/Services/MicrosoftPlannerService.swift)
  - Service to connect with Microsoft Planner via Microsoft Graph API
- `NotionService` -- [`GitMac/Core/Services/NotionService.swift:6`](GitMac/Core/Services/NotionService.swift)
  - Service to connect with Notion API
- `PatchManipulator` -- [`GitMac/Core/Git/PatchManipulator.swift:5`](GitMac/Core/Git/PatchManipulator.swift)
  - Manipulates git patches for line-level staging/discarding operations
- `RepositoryContext` -- [`GitMac/Core/Git/RepositoryContext.swift:61`](GitMac/Core/Git/RepositoryContext.swift)
  - Per-repository context that encapsulates all Git operations, caching, and file watching.
- `ShellExecutor` -- [`GitMac/Core/Utils/ShellExecutor.swift:100`](GitMac/Core/Utils/ShellExecutor.swift)
  - Executes shell commands
- `SyntaxHighlightEngine` -- [`GitMac/Features/Diff/DiffEnhancements.swift:230`](GitMac/Features/Diff/DiffEnhancements.swift)
  - On-demand syntax highlighting with cancellation support
- `TaigaService` -- [`GitMac/Core/Services/TaigaService.swift:6`](GitMac/Core/Services/TaigaService.swift)
  - Service to connect with Taiga API (tree.taiga.io)
- `TerminalSuggestionEngine` -- [`GitMac/Features/Terminal/Core/TerminalSuggestionEngine.swift:11`](GitMac/Features/Terminal/Core/TerminalSuggestionEngine.swift)
  - AI-powered suggestion engine with Ollama and fallback support
- `ViewDiffEngine` -- [`GitMac/Features/Diff/DiffEngineView.swift:44`](GitMac/Features/Diff/DiffEngineView.swift)
  - High-performance diff engine with streaming parser and on-demand materialization