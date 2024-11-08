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

Named after Batman's assistant, Robin AI is an open source Github project that automatically reviews Github pull requests, providing a score (0-100), suggested improvements, and sample code for improvement.

## Installation

To use Robin AI in your Github project, you'll need to add it as a Github action. Here's how:

1. In your Github repository, navigate to the "Actions" tab.
2. Click on the "New workflow" button.
3. Select the option to "Set up a workflow yourself".
4. Copy and paste the following code into the new file:

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

5. Save the file with a name like `robin.yml`.
6. Create a secret in your Github repository called `OPEN_AI_API_KEY` and set it to the value of your Open AI API key.

With those steps complete, Robin AI will automatically run every time a pull request is opened or edited in your Github repository.

## Arguments

| Name                | Required | Default Value             | Description                                                                                                       |
|---------------------|----------|---------------------------|-------------------------------------------------------------------------------------------------------------------|
| `GITHUB_TOKEN`      | Yes      | Automatically supplied    | A Github access token with the `repo` and `pull_request` scopes.                                                  |
| `OPEN_AI_API_KEY`   | Yes      | N/A                       | An API key from Open AI's [developer portal](https://platform.openai.com/account/api-keys).                                                                       |
| `gpt_model_name`    | No       | `gpt-3.5-turbo`           | The name of the GPT model to use for text generation.                                                             |
| `github_api_url`    | No       | `https://api.github.com`  | The URL for the Github API endpoint. (Only relevant to enterprise customers.)                                      |
| `files_to_ignore`   | No       |  (empty string)         | A whitespace delimited list of files to ignore.                                                                   |

## OPEN_AI_API_KEY

You'll have to navigate to [OpenAI's developer portal](https://platform.openai.com/account/api-keys) to generate an API key. Further, you'll have to put a card on file before the API key will become active. You can see the [pricing details here](https://openai.com/pricing), but for the default `gpt-3.5-turbo` model, pricing is `$0.0015 / 1K tokens`, which translates to < $2 / month even for organizations making daily pull requests.

## Usage

When Robin AI runs, it will post a comment on the pull request with its score out of 100, suggested improvements, and sample code for improvement. You can use this information to improve the quality of your code and make your pull requests more likely to be accepted.

## Performance
Great emphasis has been put on ensuring a performant runtime.

| Metric         | Value     |
|----------------|-----------|
| Docker Image Size  | 15.6MB   |
| Average Action Runtime | 14s |

The Docker image for Robin AI has a size of 15.6MB, which is relatively small and should be quick to download and use. On average, the Robin AI Github action runtime is 14 seconds, which means that it should be able to process pull requests quickly and efficiently. These metrics may vary depending on factors such as the size and complexity of the code being reviewed, the speed of the internet connection, and the availability of Open AI's API.

## Demo

Here's a [link to the demo](https://twitter.com/johnkuhn58/status/1656460223685509122)

## Contributing

If you'd like to contribute to Robin AI, we welcome your input! Please feel free to submit issues or pull requests on our Github repository. You may also message me [on twitter](https://twitter.com/johnkuhn58/).

## License

Robin AI is licensed under the MIT License. See `LICENSE` for more information.
# Test Changes
This is a test change to verify the AI reviewer functionality.
