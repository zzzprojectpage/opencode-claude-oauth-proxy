# OpenCode + Claude subscription via a local OAuth proxy

Use your **Claude Pro/Max subscription** with [OpenCode](https://opencode.ai) through a local, authenticated [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) instance — **no Anthropic API key required**.

```text
OpenCode  ──(Anthropic Messages API)──▶  CLIProxyAPI on 127.0.0.1:8317  ──▶  Anthropic
                                                │
                                     Claude OAuth credential (stored locally)
```

- **Local only:** the proxy binds to `127.0.0.1` and never leaves your machine.
- **No relay:** prompts go from your machine to Anthropic directly.
- **Separate credentials:** the proxy has its own access key; your Claude OAuth token stays inside the proxy's local auth directory.

> **Unofficial guide.** CLIProxyAPI is a third-party tool. Review the project and make sure your use complies with Anthropic's terms and your local policies. This guide has been tested on Windows; macOS/Linux work with equivalent commands.

## Requirements

- Windows 10/11 with PowerShell 5.1+
- [OpenCode](https://opencode.ai) (this guide is tested with OpenCode 2.x)
- A Claude Pro/Max account
- Internet access to github.com (proxy download) and to your Claude account (OAuth sign-in)

## 1. Install the proxy

Download and verify the latest official CLIProxyAPI release:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-Proxy.ps1
```

This downloads the Windows amd64 release, verifies it against the release's `checksums.txt`, and places `cli-proxy-api.exe` in `.\bin`.

## 2. Create the configuration

```powershell
Copy-Item .\config.example.yaml .\config.yaml
```

Generate a long random proxy key and put it in `config.yaml` under `access.api-keys`:

```powershell
$b = [byte[]]::new(32)
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
[Convert]::ToBase64String($b)
```

`config.yaml` and the `auth/` directory hold secrets. They are already listed in `.gitignore` — never commit or share them.

## 3. Sign in to Claude (OAuth)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Login-Claude.ps1
```

A browser opens the official Claude sign-in flow. Complete it and wait for `Claude authentication successful`. The credential is stored in `.\auth`.

## 4. Start the proxy

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Proxy.ps1
```

Leave the window open. Check it is running:

```powershell
curl.exe -i http://127.0.0.1:8317/v1/models
```

`401 Missing API key` is expected — the endpoint is up and requires your proxy key.

## 5. Configure OpenCode

Add this to your global OpenCode config (`~/.config/opencode/opencode.jsonc`; on Windows `C:\Users\<you>\.config\opencode\opencode.jsonc`):

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "providers": {
    "anthropic": {
      "settings": {
        "baseURL": "http://127.0.0.1:8317/v1"
      }
    }
  }
}
```

Then connect the credential:

```text
/connect
# Select "Anthropic" → "Manually enter API Key"
# Paste your proxy key from config.yaml (NOT your Claude OAuth token)
```

Pick a model with `/models` — for example `anthropic/claude-sonnet-5-5` or `anthropic/claude-opus-5-5`. Reasoning-effort variants (`low` … `max`) are selectable per model.

To verify from the command line:

```powershell
opencode run --model anthropic/claude-opus-5-5 "Reply with exactly: OK"
```

## How it works

- CLIProxyAPI authenticates once with Anthropic's official OAuth flow and refreshes the token locally.
- It exposes an Anthropic-compatible `/v1/messages` endpoint plus OpenAI-compatible routes on `127.0.0.1:8317`.
- OpenCode keeps using its **built-in Anthropic provider**; only the base URL is redirected to the local proxy. The API key you enter in `/connect` is the proxy's access key.
- The proxy fetches the public model catalog at startup (and every 3 hours) so newly released model IDs appear without updating the binary.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `404` on `POST /messages?beta=true` | The base URL is missing `/v1`. OpenCode sends `<baseURL>/messages?beta=true`; use `http://127.0.0.1:8317/v1`. |
| `Cannot find package '@opencode/ai'` | Some OpenCode builds cannot resolve custom provider packages. Use the built-in `anthropic` provider with the `baseURL` override exactly as above. |
| New model ID missing (e.g. `claude-sonnet-5-5`) | The proxy binary bundles an older catalog. `Start-Proxy.ps1` intentionally runs **without** `-local-model` so the catalog refreshes automatically. |
| `401 Missing API key` in OpenCode | Wrong or missing proxy key. Re-enter the value from `config.yaml` via `/connect`. |
| Model answers, but usage/billing unclear | OAuth usage is subject to your Claude subscription limits. This setup does not guarantee any particular billing behavior. |

## Security notes

- The proxy listens on loopback only. Do not expose port 8317 to a network.
- `config.yaml`, `auth/`, and `bin/` are git-ignored; keep them private.
- The proxy access key and the Claude OAuth token are different credentials — never paste the OAuth token into OpenCode or any other client.
