# MCP PWM Vision

Fork of PowerShell.MCP 1.14.2 with native MCP image output.

## Added tool

`read_image(path)` reads a local PNG/JPEG/WebP/GIF and returns a native MCP `ImageContentBlock` (`type: image`, `mimeType`, base64 data on the wire). It does not route image bytes through `execute_command`, so the normal 15,000-character PowerShell output truncation path is bypassed.

Server-side limit: 20 MB per image. Client/runtime limits can be lower.

## Build

Published Windows x64 proxy:

`dist\win-x64\PowerShell.MCP.Proxy.exe`

## Tunnel

Use:

`start-tunnel-mcp-pwv.example.bat` (copy to a local launcher and fill in your own tunnel settings).

The copied tunnel config uses profile `powershell-mcp-vision` and resolves the proxy relative to this folder:

`dist\win-x64\PowerShell.MCP.Proxy.exe`

The committed tunnel files are sanitized examples. Keep real tunnel IDs and control-plane credentials in local, ignored files.

## Verification

Run:

`pwsh .\selftest-read-image.ps1 -ImagePath "C:\path\to\image.jpg"`

The self-test performs an MCP stdio handshake, checks that `tools/list` advertises `read_image`, calls the tool, requires `content[0].type == image`, decodes the returned MCP base64, and verifies SHA-256 against the original file.

Verified with a 33,301-byte JPEG: `image/jpeg`, byte-for-byte identical over MCP.

## Client caveat

This fork fixes the MCP server side. Whether the model actually receives the image as vision input still depends on the MCP consumer/runtime preserving `ImageContent` instead of stringifying or dropping it.
