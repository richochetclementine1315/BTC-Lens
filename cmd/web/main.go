package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"

	"chain-lens/pkg/parser"
	"chain-lens/pkg/types"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	// Get port from environment or default to 3000
	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}

	// Create Gin router
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// Enable CORS for React frontend
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type"},
		AllowCredentials: true,
	}))

	// Health check endpoint
	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"ok": true})
	})

	// Analyze transaction endpoint
	r.POST("/api/analyze", handleAnalyze)

	// Serve React build (if exists)
	if _, err := os.Stat("web/build"); err == nil {
		r.Static("/static", "web/build/static")
		r.StaticFile("/", "web/build/index.html")
		r.NoRoute(func(c *gin.Context) {
			c.File("web/build/index.html")
		})
	} else {
		// Fallback: simple HTML page
		r.GET("/", func(c *gin.Context) {
			c.Data(200, "text/html", []byte(fallbackHTML))
		})
	}

	// Print URL and start server
	fmt.Printf("http://127.0.0.1:%s\n", port)
	r.Run(":" + port)
}

func handleAnalyze(c *gin.Context) {
	// Read request body
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(400, types.TransactionOutput{
			OK:    false,
			Error: &types.ErrorInfo{Code: "INVALID_REQUEST", Message: "Failed to read request body"},
		})
		return
	}

	// Parse fixture
	var fixture types.Fixture
	if err := json.Unmarshal(body, &fixture); err != nil {
		c.JSON(400, types.TransactionOutput{
			OK:    false,
			Error: &types.ErrorInfo{Code: "INVALID_JSON", Message: "Failed to parse JSON"},
		})
		return
	}

	// Parse transaction
	result, err := parser.ParseTransaction(fixture)
	if err != nil {
		c.JSON(400, types.TransactionOutput{
			OK:    false,
			Error: &types.ErrorInfo{Code: "PARSE_ERROR", Message: err.Error()},
		})
		return
	}

	c.JSON(200, result)
}

const fallbackHTML = `<!DOCTYPE html>
<html>
<head>
    <title>Chain Lens - Bitcoin Transaction Analyzer</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #f7931a; }
        textarea { width: 100%; height: 200px; font-family: monospace; }
        button { background: #f7931a; color: white; padding: 10px 20px; border: none; cursor: pointer; }
        pre { background: #f5f5f5; padding: 15px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>⛓️ Chain Lens</h1>
    <p>Paste a transaction fixture JSON below:</p>
    <textarea id="input" placeholder='{"network":"mainnet","raw_tx":"...","prevouts":[...]}'></textarea>
    <br><br>
    <button onclick="analyze()">Analyze Transaction</button>
    <h2>Result:</h2>
    <pre id="output">Results will appear here...</pre>
    
    <script>
        async function analyze() {
            const input = document.getElementById('input').value;
            const output = document.getElementById('output');
            
            try {
                const response = await fetch('/api/analyze', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: input
                });
                const result = await response.json();
                output.textContent = JSON.stringify(result, null, 2);
            } catch (err) {
                output.textContent = 'Error: ' + err.message;
            }
        }
    </script>
</body>
</html>`
