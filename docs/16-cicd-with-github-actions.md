# CI/CD with GitHub Actions

[Overview](../README.md) › Part 3: Engineering practices › Topic 16 of 17

Tests protect you only when they run, and a pipeline runs them on every
change and on every platform you support. This topic takes the GitHub Actions
workflow of the demo project apart, shows how to find the cause of a failed
run, and ends with a workflow of your own.

In this topic, you learn to:

- read the triggers, jobs, and steps of a GitHub Actions workflow
- test one build on several platforms with a matrix
- keep permissions and secrets to the minimum
- find the cause of a failed run
- reproduce every step of the pipeline on your machine

## The pipeline of the demo project

*CI/CD* stands for continuous integration and delivery: build, test, and
release automatically on every change. The workflow
`.github/workflows/ci.yml` of the demo project runs the same `build.ps1` in
GitHub Actions for every push to `main`, every version tag, and every pull
request to `main`:

![The CI pipeline: package the module, test it on four platforms, summarize
the results, and deploy](../assets/diagrams/ci-pipeline.svg)

1. **Package Module:** GitVersion calculates the version from the Git
   history, `build.ps1` builds and packages the module, and the `output`
   folder becomes a build artifact.
2. **Test:** a matrix runs the tests against this artifact on Ubuntu, on
   Windows with PowerShell 7 and with Windows PowerShell 5.1, and on macOS.
3. **Test Results:** collects the results of all platforms and writes a
   summary to the summary page of the run.
4. **Deploy Module:** runs for pushes to `main` and for version tags. The
   publish tasks skip themselves, because no API key is configured yet.

This is the [run of 17 November 2026][fms-ci-run]:

![The GitHub Actions run: Package Module, four test jobs, Test Results, and
Deploy Module all succeeded](../assets/screenshots/ci-run-graph.png)

| Platform       | Shell                  | Passed | Failed |
|----------------|------------------------|-------:|-------:|
| ubuntu-latest  | PowerShell 7           |     52 |      0 |
| windows-latest | PowerShell 7           |     52 |      0 |
| windows-latest | Windows PowerShell 5.1 |     52 |      0 |
| macos-latest   | PowerShell 7           |     52 |      0 |

To publish for real, add two repository secrets under **Settings** >
**Secrets and variables** > **Actions**:

| Secret            | Used for                                                                 |
|-------------------|--------------------------------------------------------------------------|
| `GalleryApiToken` | The PowerShell Gallery API key that publishes the module                 |
| `GitHubToken`     | A personal access token that creates the GitHub release and changelog PR |

> [!NOTE]
> Every job calls `build.ps1`. When the pipeline fails, run the same command
> on your machine and debug it there.

[fms-ci-run]: https://github.com/raandree/FileManagementSample/actions/runs/44084182216

## Jobs, needs, and runners

A *workflow* is a YAML file in the folder `.github/workflows`. It names the
*events* that start it and the *jobs* it runs. Each job runs on its own
*runner*, a new virtual machine hosted by GitHub, and consists of *steps*:
commands, or reusable *actions* such as `actions/checkout`. Because the file
is YAML, the module powershell-yaml from
[CSV, JSON, and YAML](06-csv-json-and-yaml.md) reads it. In the root of your
clone of the demo project:

```powershell
Import-Module -Name powershell-yaml
$ci = Get-Content -Path ./.github/workflows/ci.yml -Raw | ConvertFrom-Yaml -Ordered
$ci.jobs.GetEnumerator() | ForEach-Object {
    [pscustomobject]@{
        Job    = $_.Key
        Needs  = $_.Value.needs -join ', '
        RunsOn = $_.Value.'runs-on'
    }
}
```

```text
Job          Needs       RunsOn
---          -----       ------
build                    ubuntu-latest
test         build       ${{ matrix.os }}
test-summary test        ubuntu-latest
deploy       build, test ubuntu-latest
```

- **`runs-on`** chooses the runner. `${{ matrix.os }}` is an *expression*;
  GitHub fills in the value from the matrix of the job.
- **`needs`** orders the jobs. A job starts when the jobs it needs have
  succeeded. If one of them fails or is skipped, the job is skipped, too,
  unless its `if` condition says otherwise.
- **`if`** in `test-summary` says otherwise:
  `${{ !cancelled() && needs.test.result != 'skipped' }}`. The summary runs
  after failed tests, when you need it most, but not in a canceled run and
  not when the tests were skipped. GitHub recommends `!cancelled()` over
  `always()`, which runs even in a canceled run.

## Triggers and permissions

The `on` key lists the events that start a run, and `permissions` follows
right after it:

```yaml
on:
  push:
    branches:
      - main
    tags:
      - 'v*'
      - '!v*-*'
    paths-ignore:
      - CHANGELOG.md
  pull_request:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
```

- **`push`** starts a run for pushes to `main` and for tags that start with
  `v`. GitHub evaluates the patterns in order, so `!v*-*` excludes
  pre-release tags such as `v1.0.0-preview1`.
- **`paths-ignore`** skips a push when *all* changed files match a pattern: a
  push that changes only `CHANGELOG.md` starts no run.
- **`pull_request`** builds and tests every pull request to `main` before
  anyone merges it.
- **`workflow_dispatch`** adds a **Run workflow** button to the **Actions**
  tab.

At the start of each job, GitHub creates a token, `GITHUB_TOKEN`, that the
steps can use to call GitHub. `permissions` decides what the token may do;
as soon as you name one permission, all others are set to `none`. The demo
project grants read access to the contents for the whole workflow, and only
the deploy job raises it with `contents: write` and `pull-requests: write`.
That is the pattern GitHub recommends: a mistake in the test job, or in an
action it uses, can't use the token to change the repository.

## The build job

The build job checks out the code, calculates the version, builds the
module, and stores it:

```yaml
      - name: Checkout
        uses: actions/checkout@v7
        with:
          # GitVersion needs the full history to calculate the version.
          fetch-depth: 0
```

By default, `actions/checkout` fetches a single commit. GitVersion requires
an unshallow clone, so `fetch-depth: 0` fetches the whole history of all
branches and tags. The script of the GitVersion step ends by writing to two
files that GitHub provides:

```powershell
$gitVersionObject.PSObject.Properties.ForEach{
    Write-Host -Object "Setting output '$($_.Name)' with value '$($_.Value)'."
    "$($_.Name)=$($_.Value)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
Write-Host -Object "ModuleVersion (FullSemVer): $($gitVersionObject.FullSemVer)"
"## FileManagementSample $($gitVersionObject.FullSemVer)" | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
```

- **`GITHUB_OUTPUT`**: each `name=value` line becomes an *output* of the
  step, such as `steps.gitversion.outputs.NuGetVersionV2`. The job declares
  two of them as job outputs, which other jobs read as
  `needs.build.outputs.fullSemVer`, for example in their names.
- **`GITHUB_STEP_SUMMARY`**: Markdown that appears on the summary page of
  the run.

```yaml
      - name: Build & Package Module
        shell: pwsh
        env:
          ModuleVersion: ${{ steps.gitversion.outputs.NuGetVersionV2 }}
        run: ./build.ps1 -ResolveDependency -Tasks pack

      - name: Publish Build Artifact
        uses: actions/upload-artifact@v7
        with:
          name: ${{ env.buildArtifactName }}
          path: output/
          if-no-files-found: error
          retention-days: 7
```

- **`shell: pwsh`** runs the step in PowerShell 7. GitHub saves `run` as a
  temporary `.ps1` file, puts `$ErrorActionPreference = 'stop'` in front,
  and appends a line that exits with `$LASTEXITCODE`. The step stops at the
  first PowerShell error and fails when the last native command failed.
- An *artifact* is a file or folder that a job stores for later jobs and for
  download. The module is built once, and every test job tests the same
  files. `if-no-files-found: error` fails the step when the build produced
  nothing; the default only warns. `retention-days: 7` deletes the artifact
  after a week instead of after the default 90 days.

## The test matrix

A *matrix* runs the same job once per entry. The demo project lists its four
platforms under `include`, each with its own values:

```yaml
    strategy:
      fail-fast: false
      matrix:
        include:
          # ...
          - name: windows-latest (Windows PowerShell 5.1)
            artifact: windows-latest-powershell
            os: windows-latest
            shell: powershell
            arguments: '-Tasks test'
          # ...

    # A step's `shell` key does not accept the matrix context; `defaults.run` is
    # the only place that does.
    defaults:
      run:
        shell: ${{ matrix.shell }}
```

- **`fail-fast: false`** lets the other platforms finish when one of them
  fails. The default, `true`, cancels every matrix job that is still queued
  or running.
- **`defaults.run.shell`** sets the shell of every `run` step in the job. The
  context table of the GitHub Docs lists `matrix` for
  `jobs.<job_id>.defaults.run`, but has no entry for the `shell` of a step;
  hence the comment.

## The job summary

The `Test Results` job downloads the results of all platforms with
`actions/download-artifact` and runs
`./.github/scripts/Write-TestResultSummary.ps1 -Path testResults`. The
script appends Markdown to the file in `$env:GITHUB_STEP_SUMMARY`, and
GitHub shows it on the summary page of the run. With `-SummaryPath`, it
writes to any file, so it runs on your machine, too. Download the results
of the run with the GitHub CLI and try it:

```powershell
gh run download 44084182216 --repo raandree/FileManagementSample --pattern 'CodeCoverage-*' --dir ./testResults
./.github/scripts/Write-TestResultSummary.ps1 -Path ./testResults -SummaryPath ./summary.md
Get-Content -Path ./summary.md -TotalCount 14
```

```text
## Test results

4 test run(s) completed (4 passed, 0 failed)

| Total tests | Passed | Failed | Others | Pass percentage | Duration |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 208 | 208 | 0 | 0 | 100% | 15.81s |

| Test run | Outcome | Total | Passed | Failed | Others | Duration |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| CodeCoverage-macos-latest | ✅ Passed | 52 | 52 | 0 | 0 | 1.73s |
| CodeCoverage-ubuntu-latest | ✅ Passed | 52 | 52 | 0 | 0 | 4.28s |
| CodeCoverage-windows-latest-powershell | ✅ Passed | 52 | 52 | 0 | 0 | 4.54s |
| CodeCoverage-windows-latest-pwsh | ✅ Passed | 52 | 52 | 0 | 0 | 5.26s |
```

When a test fails, the summary adds a table of the failed tests with their
messages, so you see the cause without opening a log. GitHub keeps these
results for 90 days, the default of the repository; for a later run, list
the run IDs with `gh run list --repo raandree/FileManagementSample`.

## The deploy condition

```yaml
  deploy:
    name: Deploy Module ${{ needs.build.outputs.fullSemVer }}
    needs: [build, test]
    runs-on: ubuntu-latest
    # Only deploy from the upstream repository, for pushes to the default
    # branch or for version tags.
    if: >-
      github.repository_owner == 'raandree' &&
      (github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/'))
```

`>-` is YAML for "fold the following lines into one". Together with
`needs`, the job has three guards:

- **A fork never deploys**, because it belongs to another owner.
- **A pull request never deploys**: its `github.ref` is
  `refs/pull/<number>/merge`.
- **Only tested code deploys**: through `needs`, every test job must have
  succeeded.

The condition doesn't check the event, so a manual run counts, too: its
`github.ref` is the branch or tag you start it on, and **Run workflow** on
`main` deploys like a push.

The publish step passes the secrets to `build.ps1` as environment
variables, such as `GitHubToken: ${{ secrets.GitHubToken }}`. A secret that
isn't set evaluates to an empty string, and the build tasks skip themselves.
The log of the deploy job explains: "Skipping task. Variable `$GitHubToken`
not set via parent scope, as an environment variable, or passed to the build
task." That's why the run succeeded without any API key.

## Read a failed run

The history of the demo project contains two failed runs from the day of
its migration to GitHub Actions. With the GitHub CLI, a run becomes a set of
objects:

```powershell
$run = gh run view 44073236726 --repo raandree/FileManagementSample --json jobs | ConvertFrom-Json
$run.jobs | Select-Object -Property name, conclusion
```

```text
name                                                            conclusion
----                                                            ----------
Package Module                                                  failure
Test ${{ needs.build.outputs.fullSemVer }} (${{ matrix.name }}) skipped
Deploy Module ${{ needs.build.outputs.fullSemVer }}             skipped
```

The build failed, so the jobs that need it were skipped. Their names still
show the raw expressions, and there is one test job instead of four: GitHub
skipped the job before it expanded the matrix. `$run.jobs[0].steps` shows
that step 4, `Build & Package Module`, failed. Its log tells you why:

```powershell
gh run view 44073236726 --repo raandree/FileManagementSample --log-failed
```

The failed step ends with an error of `Save-PSResource`, "Response returned
status code package: Not Found.", and the annotation "Process completed with
exit code 1." On the website, GitHub expands the failed step automatically.
GitHub keeps run logs for the retention period of the repository, 90 days in
the demo project; after that, the quotes here show what the log contained.

The cause is documented in a comment in `ci.yml`: `Save-PSResource` searched
the repository MicrosoftArtifactRegistry before the PowerShell Gallery, and
the 404 it returned is a non-terminating error "that
`$ErrorActionPreference = 'stop'` in each pwsh step makes fatal". In your
console, the default is `Continue`: PowerShell displays the error and
carries on. The fix, a step that gives the PowerShell Gallery the highest
priority, failed in the next run, because a fresh runner has no repository
store yet; `$null = Get-PSResourceRepository` creates it. On a machine where
you have used PSResourceGet before, the store exists. Finding such
differences early is what CI is for.

## Local equals CI

Every job runs `build.ps1` or a script from the repository, and the YAML
does little more than call them. So whatever fails in the pipeline, you can
run on your machine:

| CI job         | Run it on your machine                                                                               |
|----------------|------------------------------------------------------------------------------------------------------|
| Package Module | `./build.ps1 -ResolveDependency -Tasks pack`                                                         |
| Test           | `./build.ps1 -Tasks test`                                                                            |
| Test Results   | `./.github/scripts/Write-TestResultSummary.ps1 -Path ./output/testResults -SummaryPath ./summary.md` |
| Deploy Module  | Leave it to the pipeline: `./build.ps1 -Tasks publish` publishes for real when the tokens are set    |

A script runs in the debugger, see
[Debugging in VS Code](12-debugging-in-vs-code.md); YAML doesn't. Keep the
logic in scripts and the YAML thin. Note that `-Tasks test` tests the last
build, just like the test job tests the build artifact; after you change the
code, run `./build.ps1`, which builds first. Three differences remain:

- **The runner is new every time.** Nothing you installed, configured, or
  cached on your machine exists there, as the failed runs show.
- **The workflow sets variables.** The build job sets `ModuleVersion` from
  GitVersion, and the deploy job sets the tokens.
- **The platform and the shell.** Your machine is one cell of the matrix.
  Run the tests in Windows PowerShell 5.1, too, before you push.

## Common pitfalls

- **Secrets in pull requests from forks.** With the exception of
  `GITHUB_TOKEN`, GitHub passes no secrets to a workflow that a fork
  triggers, so steps that need a secret must handle an empty value.
  Workflows don't even run in a fork until its owner enables them in the
  **Actions** tab of the fork.
- **`powershell` is not `pwsh`.** `shell: powershell` is Windows PowerShell
  5.1 and exists only on Windows; `shell: pwsh` is PowerShell 7 on every
  platform. A step without `shell` runs in `pwsh` on Windows, but in bash on
  Linux and macOS.
- **`fail-fast` stops the other matrix jobs.** It is `true` by default, so
  the first failing platform cancels the others, and you don't learn whether
  the failure is specific to one platform.
- **Commands after `Invoke-Pester`.** When tests fail, Pester sets
  `$LASTEXITCODE`, and a `pwsh` step exits with it. A native command after
  `Invoke-Pester`, such as `git --version`, overwrites it, and the step turns
  green despite the failed tests. `Invoke-Pester -CI` exits right away.
- **An invalid workflow file.** As long as `.github/workflows` contains an
  invalid file, GitHub generates a failed run for every new commit. Parse
  the YAML with `ConvertFrom-Yaml` before you push it. That catches syntax
  errors, not a misspelled key, so check the **Actions** tab after the push.

## Exercises

The exercises use the demo project's `ci.yml` and the `samples` folder of
this repository, whose Pester tests run on any platform.

### Exercise 1: Read the demo workflow

1. You push the tag `v1.0.0-preview1`. Does the workflow run?
2. How many jobs does a push to `main` start? Count them with `$ci`.
3. The tests fail on macOS only. Which jobs finish, which run anyway, and
   which are skipped?
4. Which job may write to the repository?

<details>
<summary>Solution</summary>

```powershell
$jobCount = 0
foreach ($job in $ci.jobs.Values) {
    if ($job.strategy) { $jobCount += $job.strategy.matrix.include.Count }
    else { $jobCount++ }
}
$jobCount
```

```text
7
```

1. No. `v*` matches, but the negative pattern `!v*-*` comes after it and
   excludes every tag with a hyphen.
2. Seven: `build`, four test jobs, `test-summary`, and `deploy`, as in the
   run of 17 November.
3. The other three test jobs finish, because `fail-fast` is `false`.
   `test-summary` runs and lists the failed tests, because its condition
   excludes only canceled runs and skipped tests. `deploy` is skipped,
   because it needs every test job to succeed.
4. Only `deploy`, through `contents: write` and `pull-requests: write`.

</details>

### Exercise 2: A workflow for the sample tests

1. In your own copy of this repository, create
   `.github/workflows/samples.yml`.
2. Run `Invoke-Pester -Path ./samples` for every push and pull request, on
   `ubuntu-latest` and `windows-latest`, in PowerShell 7.
3. Make sure that a failed test fails the job, that both platforms always
   finish, and that the token can only read.
4. Check that the file parses before you push it.

<details>
<summary>Solution</summary>

```yaml
name: Sample tests

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  test:
    name: Pester (${{ matrix.os }})
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Run the sample tests
        shell: pwsh
        run: |
          Import-Module -Name Pester -MinimumVersion 5.0.0
          Invoke-Pester -Path ./samples -Output Detailed -CI
```

```powershell
Import-Module -Name powershell-yaml
$workflow = Get-Content -Path ./.github/workflows/samples.yml -Raw | ConvertFrom-Yaml
$workflow.jobs.test.strategy.matrix.os
$workflow.jobs.test.steps.name
```

```text
ubuntu-latest
windows-latest
Checkout
Run the sample tests
```

The runner images include Pester 5, and the Windows image also Pester
3.4.0. `Import-Module -MinimumVersion` states what the tests need and fails
clearly when it's missing. `-CI` makes `Invoke-Pester` exit with an error
when a test fails, and writes the results to `testResults.xml`. Locally, all
17 tests in `samples` pass.

</details>

### Exercise 3: Start the tests by hand

1. Add a manual trigger with the input `output`: a choice of `Normal`,
   `Detailed`, and `Diagnostic`, with the default `Detailed`.
2. Pass the input to the parameter `-Output` of `Invoke-Pester`.
3. Make sure that runs from pushes and pull requests, which have no input,
   still work.

<details>
<summary>Solution</summary>

Extend `on` and the test step of your workflow:

```yaml
on:
  push:
  pull_request:
  workflow_dispatch:
    inputs:
      output:
        description: Verbosity of the Pester output
        type: choice
        options:
          - Normal
          - Detailed
          - Diagnostic
        default: Detailed
```

```yaml
      - name: Run the sample tests
        shell: pwsh
        env:
          PESTER_OUTPUT: ${{ inputs.output }}
        run: |
          $output = if ($env:PESTER_OUTPUT) { $env:PESTER_OUTPUT } else { 'Detailed' }
          Import-Module -Name Pester -MinimumVersion 5.0.0
          Invoke-Pester -Path ./samples -Output $output -CI
```

```powershell
$workflow = Get-Content -Path ./.github/workflows/samples.yml -Raw | ConvertFrom-Yaml
$workflow.on.workflow_dispatch.inputs.output.options
$workflow.on.workflow_dispatch.inputs.output.default
```

```text
Normal
Detailed
Diagnostic
Detailed
```

The `inputs` context exists only in a manual run, so for a push
`PESTER_OUTPUT` is empty and the script falls back to `Detailed`. The
environment variable keeps the input out of the script text, as GitHub
recommends for any value from outside. The **Run workflow** button appears
once the file is on the default branch; from the console, start a run with
`gh workflow run samples.yml -f output=Diagnostic`.

</details>

## Key takeaways

- A workflow lists its triggers in `on` and its jobs in `jobs`; `needs`
  orders the jobs, and `if` decides whether a job runs at all.
- Build once, store the result as an artifact, and test that artifact on
  every platform of a matrix with `fail-fast: false`.
- Give `GITHUB_TOKEN` read access by default and more only where a job needs
  it. Secrets are empty when they aren't set, and in runs from forks.
- Read a failed run from the top: the failed job, its failed step, then the
  log with `gh run view --log-failed`.
- Keep the YAML thin and the logic in scripts, so that every step runs, and
  can be debugged, on your machine.

## Learn more

- [GitHub Actions documentation](https://docs.github.com/actions)
- [Workflow syntax for GitHub Actions](https://docs.github.com/actions/reference/workflows-and-actions/workflow-syntax)
- [Running variations of jobs in a workflow (matrix)](https://docs.github.com/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations)
- [Using secrets in GitHub Actions](https://docs.github.com/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
- [Use GITHUB_TOKEN for authentication in workflows](https://docs.github.com/actions/tutorials/authenticate-with-github_token)
- [Secure use reference](https://docs.github.com/actions/reference/security/secure-use)
- [Adding a job summary](https://docs.github.com/actions/reference/workflows-and-actions/workflow-commands#adding-a-job-summary)
- [Using workflow run logs](https://docs.github.com/actions/how-tos/monitor-workflows/use-workflow-run-logs)
- [Events that trigger workflows: workflow_dispatch](https://docs.github.com/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch)
- [about_Preference_Variables: $ErrorActionPreference](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_preference_variables)
- [Pester: Invoke-Pester](https://pester.dev/docs/commands/Invoke-Pester)
- [Managing API keys for the PowerShell Gallery](https://learn.microsoft.com/powershell/gallery/how-to/managing-profile/creating-apikeys)
- [GitVersion](https://gitversion.net/)

---

[← Previous: Building with Sampler](15-building-with-sampler.md)
· [Overview](../README.md) ·
[Next: GitHub Copilot in the demo project →](17-github-copilot-in-the-demo-project.md)
