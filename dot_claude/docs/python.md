## Python

- Use an isolated virtual environment for each project, managed with mise (https://mise.jdx.dev/mise-cookbook/python.html)
- I prefer to use uv for everything (uv add, uv run, etc)
- Do not use old fashioned methods for package management like poetry, pip or easy_install.
- Make sure that there is a pyproject.toml file in the root directory.
- If there isn't a pyproject.toml file, create one using uv by running uv init.
- Never use a requirements.txt file: always put dependencies in pyproject.toml.
- Do not manage dependencies manually: use uv for dependency management.
do