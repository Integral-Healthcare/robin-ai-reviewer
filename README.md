<div align="center">
  <h1>Robin AI</h1>
  <a href="https://github.com/Integral-Healthcare/robin-ai-reviewer/releases">
    <img src="https://img.shields.io/github/v/release/Integral-Healthcare/robin-ai-reviewer" alt="GitHub release (latest by date)">
  </a>
  <a href="https://github.com/Integral-Healthcare">
    <img src="https://img.shields.io/badge/org-Integral--Healthcare-blue" alt="GitHub org">
  </a>
  <br>
  <img src="/assets/robin.png" alt="Robin watercolor image" style="width: 350px;"/>
</div>

Named after Batman's assistant, Robin AI is an open source GitHub Action and GitLab CI job that automatically reviews pull requests and merge requests using AI models from OpenAI (GPT) or Anthropic (Claude). It analyzes your code changes and provides:
- A quality score (0-100)
- Actionable improvement suggestions
- Sample code snippets for better implementation
- Fast, automated feedback (average runtime: 14s)

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Example Output](#example-output)
- [Performance](#performance)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites
- A GitHub repository with pull request workflows or a GitLab project with merge request pipelines
- An API key for your chosen AI provider:
  - **OpenAI**: [Get an API key here](https://platform.openai.com/account/api-keys)
  - **Claude (Anthropic)**: [Get an API key here](https://console.anthropic.com/settings/keys)

## Installation

### GitHub Actions

1. In your Github repository, navigate to the "Actions" tab
2. Click "New workflow"
3. Choose "Set up a workflow yourself"
4. Create a new file (e.g., `robin.yml`) with one of these configurations:

### Using OpenAI (Default)
```yml
name: Robin AI Reviewer

on:
  pull_request:
    branches: [main]
    types:
      - opened
      - reopened
      - ready_for_review

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      - name: Robin AI Reviewer
        uses: Integral-Healthcare/robin-ai-reviewer@v[INSERT_LATEST_RELEASE]
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          AI_PROVIDER: openai
          AI_API_KEY: ${{ secrets.OPEN_AI_API_KEY }}
          AI_MODEL: gpt-5-mini
          files_to_ignore: |
            "README.md"
            "assets/*"
            "package-lock.json"
```

### Using Claude (Anthropic)
```yml
name: Robin AI Reviewer

on:
  pull_request:
    branches: [main]
    types:
      - opened
      - reopened
      - ready_for_review

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      - name: Robin AI Reviewer
        uses: Integral-Healthcare/robin-ai-reviewer@v[INSERT_LATEST_RELEASE]
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          AI_PROVIDER: claude
          AI_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
          AI_MODEL: claude-sonnet-4-5
          files_to_ignore: |
            "README.md"
            "assets/*"
            "package-lock.json"
```

### Legacy Configuration (Still Supported)
```yml
name: Robin AI Reviewer

on:
  pull_request:
    branches: [main]
    types:
      - opened
      - reopened
      - ready_for_review

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      - name: Robin AI Reviewer
        uses: Integral-Healthcare/robin-ai-reviewer@v[INSERT_LATEST_RELEASE]
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          OPEN_AI_API_KEY: ${{ secrets.OPEN_AI_API_KEY }}
          gpt_model_name: gpt-5-mini
          files_to_ignore: |
            "README.md"
            "assets/*"
            "package-lock.json"
```

5. Add your API key as a repository secret:
   - Go to repository Settings → Secrets and Variables → Actions
   - For OpenAI: Create a secret named `OPEN_AI_API_KEY`
   - For Claude: Create a secret named `CLAUDE_API_KEY`
   - Paste your API key as the value

### GitLab CI

Robin AI runs in GitLab CI from the published Docker image. Add a project or personal access token with the `api` scope as a CI/CD variable named `GITLAB_TOKEN`, plus the API key for your selected AI provider.

```yml
robin_ai_review:
  image:
    name: ghcr.io/integral-healthcare/robin-ai-reviewer:latest
    entrypoint: [""]
  stage: test
  script:
    - >
      /entrypoint.sh
      --git_provider=gitlab
      --git_token="${GITLAB_TOKEN}"
      --ai_provider=openai
      --ai_api_key="${OPEN_AI_API_KEY}"
      --ai_model=gpt-5-mini
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

For Claude, set `--ai_provider=claude`, pass your Claude API key to `--ai_api_key`, and set `--ai_model` to the Claude model you want to use.

## Configuration

### GitHub Action Parameters
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `GITHUB_TOKEN` | Yes | Auto-supplied | GitHub token for API access |
| `AI_PROVIDER` | No | `openai` | AI provider to use (`openai` or `claude`) |
| `AI_API_KEY` | Yes | N/A | API key for the selected AI provider |
| `AI_MODEL` | No | Provider-specific | AI model to use (see supported models below) |
| `github_api_url` | No | `https://api.github.com` | GitHub API URL (for enterprise) |
| `files_to_ignore` | No | (empty) | Files to exclude from review |

### Docker and GitLab Arguments
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `git_provider` | No | `github` | Git provider to review (`github` or `gitlab`) |
| `git_token` | Yes for GitLab | N/A | GitLab token with the `api` scope |
| `ai_provider` | No | `openai` | AI provider to use (`openai` or `claude`) |
| `ai_api_key` | Yes | N/A | API key for the selected AI provider |
| `ai_model` | No | Provider-specific | AI model to use |
| `files_to_ignore` | No | (empty) | Files to exclude from review |

### Legacy Parameters (Deprecated — removed in v2.0, target 2026-Q3)
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `OPEN_AI_API_KEY` | No | N/A | [DEPRECATED] Use `AI_API_KEY` instead. Will be removed in v2.0 (target 2026-Q3). |
| `gpt_model_name` | No | N/A | [DEPRECATED] Use `AI_MODEL` instead. Will be removed in v2.0 (target 2026-Q3). |

### Supported Models

Robin AI passes the value of `AI_MODEL` straight through to the upstream provider, so any model your account has access to should work. Defaults are kept current with the latest GA release of each provider.

**OpenAI** (default: `gpt-5-mini`)
- `gpt-5`, `gpt-5-mini`, `gpt-5-nano`
- `gpt-4.1`, `gpt-4.1-mini`
- Reasoning models such as `o3`, `o4-mini` are also accepted.

**Anthropic Claude** (default: `claude-sonnet-4-5`)
- `claude-opus-4-5`
- `claude-sonnet-4-5`
- `claude-haiku-4-5`

If you need a specific model snapshot (e.g., `claude-sonnet-4-5-20250929`), pass the dated alias directly via `AI_MODEL`.

## Usage

When Robin AI runs, it will post a comment on the pull request or merge request with its score out of 100, suggested improvements, and sample code for improvement. You can use this information to improve the quality of your code and make your pull requests more likely to be accepted.

## Example Output
When Robin AI reviews your pull request, you'll see a comment like this:

<details>
<summary>Score: 85/100</summary>

Improvements:
- Consider adding input validation for the user parameters
- The error handling could be more specific
- Variable naming could be more descriptive

```python
# Before
def process(x):
    return x * 2

# After
def process_user_input(value: int) -> int:
    if not isinstance(value, int):
        raise ValueError("Input must be an integer")
    return value * 2
```
</details>

## Performance
- Docker Image Size: 15.6MB
- Average Runtime: 14 seconds
- Memory Usage: Minimal (<100MB)

## Demo
See Robin AI in action: [View Demo](https://twitter.com/johnkuhn58/status/1656460223685509122)

## Contributing
We welcome contributions! Here's how you can help:
- Submit bug reports or feature requests through [Issues](https://github.com/Integral-Healthcare/robin-ai-reviewer/issues)
- Submit pull requests for bug fixes or new features
- Improve documentation
- Share feedback on [Twitter](https://twitter.com/johnkuhn58/)

## License
Robin AI is MIT licensed. See [LICENSE](LICENSE) for details.
