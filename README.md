# SPHinXsistant

A repository-grounded AI assistance over the SPHinXsim (including SPHinXsys library) upstream repositories. SPHinXsys and SPHinXsim are open-source C++ multi-physics SPH library and simulator based on an unified computational framework using Smoothed Particle Hydrodynamics (SPH). 

This project provides a local Gradio interface for users to ask questions about the SPHinXsys and SPHinXsim repositories, retrieve relevant code chunks, and receive grounded answers from an LLM.

## Repository layout

```text
SPHinXsistant/
|-- apps/       # Local Gradio interface
|-- configs/    # Project-owned configuration
|-- data/       # Corpus, evaluation, and user-testing data
|-- doc/        # Project documentation
|-- repos/      # Read-only full upstream clones (not stored in this Git repo)
|-- scripts/    # Chunking, retrieval, answer, and user-testing CLIs
|-- src/        # Project-owned Python modules
|-- tests/
`-- tools/     # Local third-party tool checkout (not stored here)
```

`repos/SPHinXsys` and `repos/SPHinXsim` are external, read-only upstream
source repositories. Do not put assistant code in them or modify source files.
They are full Git clones because synchronization and diff-based processing need
repository history. `tools/treesitter-chunker` is an external local dependency.
Generated local user-testing output is not authoritative project source code.

## Local setup (Ubuntu 24.04)

### 1. Clone the assistant project and upstream repositories

Choose one assistant-project clone option:

Official / supervisor repository:

```bash
git clone https://github.com/Xiangyu-Hu/SPHinXsistant.git
cd SPHinXsistant
```

Or use the development mirror:

```bash
git clone https://github.com/XiangruZhang007/SPHinX_AI_Assistant.git
cd SPHinX_AI_Assistant
```

After either option, clone the upstream repositories:

```bash
mkdir -p repos tools
git clone https://github.com/Xiangyu-Hu/SPHinXsys.git repos/SPHinXsys
git clone https://github.com/Xiangyu-Hu/SPHinXsim.git repos/SPHinXsim
```

Do not use `--depth 1`. Confirm both clones are non-shallow:

```bash
git -C repos/SPHinXsys rev-parse --is-shallow-repository
git -C repos/SPHinXsim rev-parse --is-shallow-repository
```

Both commands must print `false`. For the current validated V1 prototype,
check out the upstream snapshots used to generate and validate the corpus,
retrieval pipeline, and user-testing workflow:

```bash
git -C repos/SPHinXsys checkout 5dec24e4731e5ad8e45cc7f7191cda19871f410f
git -C repos/SPHinXsim checkout 90375915a25d6f16ea6c496264171f15df14b007

git -C repos/SPHinXsys rev-parse HEAD
git -C repos/SPHinXsim rev-parse HEAD
```

`git clone` retrieves repository history, even if the initial working tree points
to the current upstream `HEAD`; the subsequent pinned `git checkout` moves the
local source tree to the exact snapshot used by this prototype. The final
commands should print the respective SHA values above. These checkouts
intentionally use detached `HEAD` state. Testers should use these pins rather
than unvalidated newer upstream code. Future updates belong to a separate
repository-refresh/CI workflow.

`data/chunks/source_chunks_v1_combined.jsonl` is already committed and used by
the current Retrieval V1 and grounded-answer prototype. The pinned upstream
clones remain necessary for source inspection, repository-version validation,
future corpus regeneration, diff/update processing, and deeper source mapping.

### 2. Create the dedicated Python environment

```bash
sudo apt-get update
sudo apt-get install -y python3.12-venv

git clone https://github.com/Consiliency/treesitter-chunker.git tools/treesitter-chunker
git -C tools/treesitter-chunker checkout fb70922076c773d1865176329a03f67ff893fd90
python3.12 -m venv tools/treesitter-chunker/.venv
tools/treesitter-chunker/.venv/bin/python -m pip install --upgrade pip
tools/treesitter-chunker/.venv/bin/python -m pip install -e tools/treesitter-chunker
tools/treesitter-chunker/.venv/bin/python -m pip install \
  openai==3.15.0 gradio==6.27.0 markdown-it-py==4.2.0
```

Verify the essential imports:

```bash
tools/treesitter-chunker/.venv/bin/python -c \
  "import chunker, gradio, openai; print('environment ready')"
```

`fb70922076c773d1865176329a03f67ff893fd90` is the external Tree-sitter chunker
version used by the current validated local prototype.

### 3. Use the prototype locally

The committed combined corpus is
`data/chunks/source_chunks_v1_combined.jsonl`.

Run lexical retrieval without an LLM:

```bash
env -u PYTHONPATH -u PYTHONHOME PYTHONDONTWRITEBYTECODE=1 \
tools/treesitter-chunker/.venv/bin/python \
scripts/retrieve_v1.py \
  --query "What does WeaklyCompressibleFluid do?" \
  --top-k 5
```

For grounded answering or the Gradio app, configure the tested NVIDIA
OpenAI-compatible provider in the current terminal:

```bash
export LLM_API_KEY="your API key"
export LLM_MODEL="your model name"
export LLM_BASE_URL="your OpenAI-compatible API base URL"
```

```bash
echo "API_KEY set? ${LLM_API_KEY:+yes}"
echo "MODEL=$LLM_MODEL"
echo "BASE_URL=$LLM_BASE_URL"
```

Never commit API keys or store them in repository files. Environment variables
apply only to the current terminal unless configured elsewhere by the user.

Start the local Gradio interface from the project root:

```bash
env -u PYTHONPATH -u PYTHONHOME PYTHONDONTWRITEBYTECODE=1 \
tools/treesitter-chunker/.venv/bin/python \
apps/gradio_app_v1.py
```

Gradio runs locally; open the URL printed in the terminal (commonly
`127.0.0.1:7860`). No public or central deployment is currently claimed.

### Recommended Docker workflow

The Docker workflow is an alternative to the manual setup above. Docker users
do not need to create the local Python environment or manually clone
SPHinXsys, SPHinXsim, or treesitter-chunker on the host. Docker is recommended
for testers; the manual setup remains available for development, debugging,
and direct local execution. The two workflows are alternatives, not sequential
requirements.

It requires Docker Engine or Docker Desktop, a project clone with Git metadata,
and an NVIDIA API key for the currently tested provider. From the project root,
configure the provider in the current terminal:

```bash
export LLM_API_KEY="your API key"
export LLM_MODEL="your model name"
export LLM_BASE_URL="your OpenAI-compatible API base URL"
```

```bash
echo "API_KEY set? ${LLM_API_KEY:+yes}"
echo "MODEL=$LLM_MODEL"
echo "BASE_URL=$LLM_BASE_URL"
```

Then launch:

```bash
./scripts/run_docker.sh
```

The script builds the Docker image automatically. Open
`http://127.0.0.1:7860` in a browser and use `Ctrl+C` to stop the
container. Gradio binds to `0.0.0.0:7860` inside the container as expected;
`data/user_testing/` is bind-mounted, so session JSONL persists after the
container exits.

For repository questions and feedback actions (**Helpful**, **Needs review**,
and **Suggested correction**), this one-command Docker launch is sufficient.
To perform an actual Submission V1 `push`, the tester must additionally have
local Git identity configuration, GitHub SSH authentication through an active
`ssh-agent`, and write permission for the selected remote (normally
`origin`). The private SSH key is not copied into the container; host
`known_hosts` is mounted read-only when SSH forwarding is enabled, and HTTPS
GitHub remotes are rewritten to SSH only inside the container. Host remote
configuration is not modified.

For Docker Submission V1 `dry-run`, no additional GitHub write operation is
performed. For `push`, configure `git user.name` and `git user.email` on
the host and verify SSH authentication manually, for example:

```bash
ssh -T git@github.com
```

GitHub does not provide an interactive shell, so inspect its authentication
message rather than treating a non-zero exit status alone as failure. Do not
store private SSH keys, access tokens, or other authentication credentials in
the project, session JSONL, or Gradio UI.

### 4. User testing and Submission V1

1. Enter a tester ID in Gradio and ask repository questions.
2. Successful interactions are stored in
   `data/user_testing/<tester_id>/session_*.jsonl`.
3. Testers can mark interactions as **Helpful** or **Needs review**, and may
   provide a suggested correction.
4. Feedback remains unreviewed until human review. It does not automatically
   improve the model or become approved repository knowledge.
5. The current session can be submitted through the Gradio **Submission**
   section.

The Submission controls provide a remote selector, `dry-run`, `no-push`,
and `push` modes, plus **Submit current session**:

- `dry-run` validates without staging, committing, or pushing.
- `no-push` validates, stages exactly the selected session, creates a local
  commit, and does not push.
- `push` validates, stages exactly the selected session, creates a commit if
  needed, and pushes to the selected remote.

For the current normal tester workflow:

1. Select the project remote, normally `origin`.
2. Select `dry-run` and click **Submit current session**.
3. If the dry-run succeeds, switch directly to `push`.
4. Click **Submit current session** again.

**Do not use `no-push` in the current normal tester workflow.** `no-push`
creates a local commit without pushing. If that same session is later submitted
in `push` mode, Submission V1 currently detects it as already committed and
returns "Nothing to submit" instead of pushing the existing local commit.
Therefore use `dry-run` followed directly by `push`. This is a known current V1
limitation, not intended final behavior.

Using `push` mode requires authenticated local Git/GitHub credentials and write
permission for the selected remote. Public repository access is sufficient for
clone/pull but not for push. No GitHub token should be stored in this project,
this README, session JSONL, or the Gradio UI; authentication is handled by the
tester's local Git/GitHub credential setup. The development-only
`data/user_testing/local_tester/` directory should not be submitted. A push
failure preserves the local commit and does not rewrite history. Submission V1
does not claim automatic multi-user conflict resolution.

### 5. Export and aggregate user-testing feedback

JSONL is the authoritative structured testing record. Markdown is a
deterministic, human-readable reviewer view for supervisors and expert
reviewers.

Export one session:

```bash
tools/treesitter-chunker/.venv/bin/python \
scripts/export_user_testing_session_md.py \
  --session data/user_testing/tester_demo/session_<...>.jsonl
```

Export one tester directory:

```bash
tools/treesitter-chunker/.venv/bin/python \
scripts/export_user_testing_session_md.py \
  --input-dir data/user_testing/tester_demo/
```

Export all tester sessions:

```bash
tools/treesitter-chunker/.venv/bin/python \
scripts/export_user_testing_session_md.py \
  --all-sessions
```

The default output is
`data/user_testing/markdown_exports/<tester_id>/<session_id>.md`. Each report
contains session metadata, Helpful/Needs Review/Unrated summaries,
needs-review categories, question, answer, feedback, suggested correction, a
compact source list, and review status. Export uses no LLM inference, does not
modify source JSONL, and leaves suggested corrections unreviewed.

Aggregate review-relevant feedback across sessions:

```bash
tools/treesitter-chunker/.venv/bin/python \
  scripts/aggregate_user_testing_feedback.py

tools/treesitter-chunker/.venv/bin/python \
  scripts/aggregate_user_testing_feedback.py --only-unreviewed
```

The Markdown exporter produces human-readable per-session reports. Feedback
aggregation selects review-relevant interactions across sessions into review
batches under `data/user_testing/review_batches/`; it does not modify source
sessions or approve corrections.

## Prototype scope

Current V1 implements:

- structural chunk generation;
- a combined SPHinXsys/SPHinXsim corpus;
- lexical Retrieval V1;
- repository-grounded LLM answering;
- a local Gradio interface;
- user-testing session logging and feedback persistence;
- review-batch aggregation;
- safe Submission V1 CLI and Gradio Submission V1 integration; and
- deterministic JSONL-to-Markdown export.

Still planned or not implemented:

- embeddings and a vector database;
- supervisor approval/rejection workflow and approved-answer reuse;
- automatic CI-based upstream repository refresh;
- a full explicit SPHinXsim-to-SPHinXsys source-level mapping graph;
- centralized deployment; and
- automatic multi-user synchronization and conflict handling.
