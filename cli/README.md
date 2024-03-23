# RouterOS Agent Script Formatter CLI

The RouterOS Agent Script Formatter CLI is a command-line utility built with Node.js that integrates with Bun for formatting RouterOS agent scripts.

## Installation

1. Ensure you have BunJS installed on your machine.

## Usage

```bash
bun install
```
## Bun Integration

This CLI tool integrates with Bun for seamless formatting of RouterOS agent scripts. It reads the content of the specified script file, formats it, and generates a new script file with the formatted content. The new script file is named `formatted-<original_filename>.rsc` and is placed in the same directory as the original file.

## Example

```bash
bun cli myscript.rsc
```

This command will process the `myscript.rsc` file using Bun, generating a formatted version named `formatted-myscript.rsc`.