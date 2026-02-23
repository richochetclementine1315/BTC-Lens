# BTC Lens

BTC Lens is a Bitcoin blockchain analysis toolkit featuring a CLI and a web interface. It enables parsing, grading, and visualizing Bitcoin blocks and transactions. The project uses Go (with Gin for the web backend), React (JSX), and Bash scripts. CI/CD is managed via GitHub Actions.

---

## Features

- **CLI Tool**: Analyze and grade Bitcoin blocks and transactions from the command line.
- **Web Interface**: Visualize blockchain data interactively with a React frontend and Go backend.
- **Automated Grading**: Scripts to test and grade block/transaction parsing.


---

## CLI Test results

- **Transaction Graders Test Results**

![alt text](<Screenshot 2026-02-23 174826.png>)

- **Block Graders Test Results**

![alt text](<Screenshot 2026-02-23 174854.png>)


## Project Structure

```
chain-lens-cli         # CLI binary (built)
chain-lens-web         # Web backend binary (built)
cli.sh                 # CLI helper script
cmd/
  cli/                 # CLI main.go
  web/                 # Web backend main.go
fixtures/              # Test data (blocks, transactions)
grader/                # Grading scripts and expected outputs
pkg/                   # Go packages (analyzer, parser, types, utils)
web/                   # React frontend (Vite, JSX)
```

---

## CLI Usage

### 1. Build CLI
```bash
go build -o chain-lens-cli ./cmd/cli && echo "CLI build OK"
```

### 2. Run Full Grader (Block + Transaction Tests)
```bash
./grade.sh
```

### 3. Manual Transaction Test (Check No DEBUG Output Leaks to stderr)
```bash
./chain-lens-cli fixtures/transactions/$(ls fixtures/transactions/ | head -1)
```

---

## Web Usage

Open **two Git Bash tabs**:

### Tab 1 — Go Web Backend
```bash
go build -o chain-lens-web ./cmd/web && ./chain-lens-web
# Should print: http://127.0.0.1:3000
```

### Tab 2 — Vite Dev Server (React)
```bash
cd web
npm install    # first time only
npm run dev
```

---

## Tech Stack
- **Go** (Gin web framework)
- **React** (JSX, Vite)
- **Shell/Bash** (build/test scripts)
- 

---



---

## Contributing

1. Fork the repo and create a feature branch.
2. Make your changes and add tests if needed.
3. Run all tests and ensure the CLI and web build cleanly.
4. Submit a pull request.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
