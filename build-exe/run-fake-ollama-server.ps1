$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 11434)
$listener.Start()

while ($true) {
    # Wait for a client connection
    if (-not($listener.Pending())) {
        Start-Sleep -Milliseconds 100
        continue
    }
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = [System.IO.StreamReader]::new($stream)
    $reader.BaseStream.ReadTimeout = 2000
    $writer = [System.IO.StreamWriter]::new($stream)
    $writer.NewLine = "`r`n"
    $writer.AutoFlush = $true
    # Read request line
    $requestLine = $reader.ReadLine()
    if (-not $requestLine) {
        $client.Close()
        continue
    }
    $parts = $requestLine.Split(' ')
    $method = $parts[0]
    $path   = $parts[1]
    # Read headers
    $contentLength = 0
    while ($true) {
        $headerLine = $reader.ReadLine()
        if ($null -eq $headerLine -or $headerLine -eq '') {
            break
        }
        if ($headerLine -match '^Content-Length:\s*(\d+)') {
            $contentLength = [int]$Matches[1]
        }
    }
    # Read body
    $requestBody = ''
    if ($contentLength -gt 0) {
        $bodyChars = New-Object char[] $contentLength
        $null = $reader.ReadBlock($bodyChars, 0, $contentLength)
        $requestBody = -join $bodyChars
    }
    # Prepare response
    $responseContentType = 'text/plain'
    if ($method -eq 'POST' -and $path -eq '/api/generate') {
        $responseStatus = '400 Bad Request'
        $responseBody = 'Invalid response'
        try {
            $requestData = $requestBody | ConvertFrom-Json
            $prompt = $requestData.prompt
            $responseStatus = '200 OK'
            $responseContentType = 'application/json'
            $responseObj = @{
                response = "Ollama answer to prompt $prompt"
            }
            $responseBody = $responseObj | ConvertTo-Json -Depth 10 -Compress
        } catch {
            $responseBody = "Error parsing JSON: $($_.Exception.Message)"
        }
    } else {
        $responseStatus = '404 Not Found'
        $responseBody = 'not found'
    }
    # Send response
    $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($responseBody)
    $writer.WriteLine("HTTP/1.1 $responseStatus")
    $writer.WriteLine("Content-Type: $responseContentType")
    $writer.WriteLine("Content-Length: $($responseBytes.Length)")
    $writer.WriteLine('Connection: close')
    $writer.WriteLine()
    $stream.Write($responseBytes, 0, $responseBytes.Length)
    $client.Close()
}
