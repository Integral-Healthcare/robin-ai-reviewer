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

Named after Batman's assistant, Robin AI is an open source Github action that automatically reviews pull requests using GPT-4. It analyzes your code changes and provides:
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
- A GitHub repository with pull request workflows
- An OpenAI API key ([Get one here](https://platform.openai.com/account/api-keys))

## Installation
1. In your Github repository, navigate to the "Actions" tab
2. Click "New workflow"
3. Choose "Set up a workflow yourself"
4. Create a new file (e.g., `robin.yml`) with this configuration:

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
          files_to_ignore: |
            "README.md"
            "assets/*"
            "package-lock.json"
```

5. Add your OpenAI API key:
   - Go to repository Settings → Secrets and Variables → Actions
   - Create a new secret named `OPEN_AI_API_KEY`
   - Paste your OpenAI API key as the value

## Configuration

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `GITHUB_TOKEN` | Yes | Auto-supplied | GitHub token for API access |
| `OPEN_AI_API_KEY` | Yes | N/A | OpenAI API key |
| `gpt_model_name` | No | `gpt-4-turbo` | GPT model to use |
| `github_api_url` | No | `https://api.github.com` | GitHub API URL (for enterprise) |
| `files_to_ignore` | No | (empty) | Files to exclude from review |

## Usage

When Robin AI runs, it will post a comment on the pull request with its score out of 100, suggested improvements, and sample code for improvement. You can use this information to improve the quality of your code and make your pull requests more likely to be accepted.

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
